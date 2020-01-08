function [] = Stories_Task(SubjectNumber, iStory, Reader, is_debugging, isMEG)

%% NyU STOries (NUTSO) MEG Task Code
% Created by Omri Raccah (October, 2019)
% Reader (0) = Michael, Reader (1) = Samantha

% 10/09/19: Edited by Arianna Zuanazzi: added voice recording for story
% recall and changed names of variables to save them into structures
% 11/05/19: Edited by Arianna Zuanazzi: added the eyetracking part of the
% code to acquire eyemovements data

%% Checks
questdlg('Turn off exhaust fan!');

%% Param to skip story

stim.skip_story = 1; %want to skip the story for debugging?
%stim.storyOrder = inputdlg('Stories order?');
eye.record_eye = 1; %want to record eyemovements?

%% Set base directory 

folder.mainFolder = '/Users/megadmin/Desktop/Experiments/Omri';
cd (folder.mainFolder);

folder.expFolder = 'Stories_Project-master';

%Initialize subject string
if SubjectNumber < 10
    folder.SubjStr = ['S0' num2str(SubjectNumber)];
else
    folder.SubjStr = ['S', num2str(SubjectNumber)];
end

folder.iStory = iStory;

if Reader == 0
    folder.reader = 'M';
elseif Reader == 1
    folder.reader = 'F';
end

folder.basedir = [pwd,'/', folder.expFolder];
folder.Savefolder = [folder.basedir, '/', sprintf('%s%sStory%sReader%s', folder.SubjStr, '/', num2str(folder.iStory), folder.reader)];

mkdir (folder.Savefolder);

%% Initialize task vars

stim.ntimespressed = 2;% secs for 4123press for end recalling part
stim.white = [255 255 255];
stim.gray = [128 128 128];
stim.green = [0 200 0];
stim.textSize = 25;
stim.textSpace = 15;
stim.fixCrossSize = 60;

%Define PTB global variables % WHAT DOES THIS ERROR MEAN
global PTBTextSize;
global PTBTextColor;
global PTBRecordAudioFileNames
global PTBLastKeyPress;
global PTBLastPresentationTime;
global PTBSoundNameFirst
global PTBIsDebugging
global PTBSoundInputDevice;
global peanuts
global PTBSoundKeyLevel

%Set screen params
Screen('Preference', 'SkipSyncTests', 1);
%screen number and open window
eye.screennumber = max(Screen('Screens'));
%screen.window = 10; %taken from [screen.window] = Screen('OpenWindow', screen.number)
%[screen.cx, screen.cy] = RectCenter([0 0 1024 768]); %projector parameters for screen
%Set text color
PTBTextColor = stim.white;
%Set text size	
PTBTextSize = stim.textSize; 
%Set background color
PTBSetBackgroundColor(stim.gray);
%Set text font	
PTBSetTextFont('Arial'); 	
%Ensure up-to-date PTB version
PTBVersionCheck(1,1,5,'at least');
%Set PTB to debugging mode
PTBSetIsDebugging(is_debugging);
%"q" key press will quit the program
PTBSetExitKey('q'); 
button_box_id = 1; % pointer to MEG button box
%Initialize trigger values
trig.values = [1]; 

%% Initialize audio recording  

%Sound sampling frequency
rec.freq = 48000;

%Sound volume level and voice threshold
stim.audio.vol = 0.6; %stimulus volume
rec.threshold = 0.07; %threshold to record voice
rec.duration = 600; %duration of recording
rec.repetitions = 0; %0:infinite repetitions, ie.,until manually stopped via the ‘Stop’ subfunction
rec.when = 0; %starttime of playback: 0: immediately
rec.waitForStart = 1; %wait for sound onset?
rec.max = []; %max amount of recorded data (optional)
rec.min = []; %min amount of recorded data (optional)

%Initialize PsychPortAudio sound driver: 
stim.audio.latLev = 1; %Set low level latency mode with compensation for hardware's inherent latency 
InitializePsychSound(stim.audio.latLev);
% PsychPortAudio('GetDevices')

%Open sound device for recording
rec.reqLatencyClass = 2; %how aggressive about minimizing sound latency and getting good deterministic timing (0: don’t care)
rec.mode = 2; %2 == audio capture
rec.channels = 1; %number of channels

parec = PsychPortAudio('Open', 2, rec.mode, rec.reqLatencyClass, rec.freq, rec.channels); %Open portaudio for recording sound: from USB audio channels

%% Set keyboard parameters

%get the devices attached
%[a b] = GetKeyboardIndices;

%find the button box index and pass it to kbcheck so that kbcheck only listens
%for the button box
%BBidx = a(strmatch('904',b));

%% Store speaker path and audiofile name

%Load story read by male speaker
if Reader == 0
    
    folderIn = [folder.basedir, '/', 'Story_AudioFiles/Michael/'];
    
elseif Reader == 1
   
     folderIn = [folder.basedir, '/', 'Story_AudioFiles/Samantha/'];
    
end

wav_file = ['s', num2str(iStory), '.wav'];

%% Initiate encoding output data [matrix with my encoding data]

StoryDataFile = cell(2,4);
StoryDataFile{1,1} = 'Story_Number'; % trial number out of 30
StoryDataFile{1,2} = 'Reader'; % The file name for the word
StoryDataFile{1,3} = 'Story_OnsetTime'; % time of stim onset relative to task-onset
StoryDataFile{1,4} = 'Recollection_OnsetTime'; % time of stim onset relative to task-onset

%Flush key events: ensures that Last[Key/Presentation]Time functions work as expected
FlushEvents('keyDown')

%% Initiate eyetracker
if eye.record_eye == 1
        
%Settings
windowPtr=Screen('OpenWindow', eye.screennumber); %select screen
%display instructions for calibration
Screen(windowPtr, 'FillRect', stim.gray); 
DrawFormattedText(windowPtr, sprintf('%s', 'Eyetracking calibration: follow the dots with your eyes!'), 'center', 'center', stim.white);
Screen('Flip', windowPtr);
%eyetracking settings
eye.el = EyelinkInitDefaults(windowPtr);
WaitSecs(5);
Screen('Close');

%Initialization of the connection with the eyetracker.
eye.online = EyelinkInit(0, 1);
if ~eye.online
   error('Eyelink Init aborted.\n');
   %cleanup routine: Shutdown Eyelink:
   Eyelink('Shutdown');
   eye.online = 0;
return;
end

%Calibrate the eyetracker
EyelinkDoTrackerSetup(eye.el);
    
%edf link
eye.edfFile = sprintf('%s.edf', num2str(SubjectNumber));
res = Eyelink('Openfile', eye.edfFile);
Eyelink('Command', 'add_file_preamble_text = "Experiment recording of participant %s', num2str(SubjectNumber));
if res~=0
   fprintf('Cannot create EDF file ''%s'' ', eye.edfFile);
   % Cleanup routine:Shutdown Eyelink
   Eyelink('Shutdown');
   eye.online = 0;
return;
end
    
%Make sure we're still connected.
if Eyelink('IsConnected')~=1
return;
end
    
%Use conservative online saccade detection (cognitive setting)
Eyelink('Command', 'recording_parse_type = GAZE');
Eyelink('Command', 'saccade_velocity_threshold = 30');
Eyelink('Command', 'saccade_acceleration_threshold = 9500');
Eyelink('Command', 'saccade_motion_threshold = 0.1');
Eyelink('Command', 'saccade_pursuit_fixup = 60');
Eyelink('Command', 'fixation_update_interval = 0');

%Other tracker configurations
Eyelink('Command', 'calibration_type = HV5');
Eyelink('Command', 'generate_default_targets = YES');
Eyelink('Command', 'enable_automatic_calibration = YES');
Eyelink('Command', 'automatic_calibration_pacing = 1000');
Eyelink('Command', 'screen_pixel_coords = 0 0 1024 768'); %%% screen resolution
Eyelink('Command', 'binocular_enabled = NO');
Eyelink('Command', 'use_ellipse_fitter = NO');
Eyelink('Command', 'sample_rate = 2000');
Eyelink('Command', 'elcl_tt_power = %d', 3); % illumination, 1 = 100%, 2 = 75%, 3 = 50%

%Set edf data
Eyelink('Command', 'file_event_filter = LEFT,FIXATION,SACCADE,BLINK,MESSAGE,INPUT');
Eyelink('Command', 'file_sample_data  = LEFT,GAZE,GAZERES,HREF,PUPIL,AREA,STATUS,INPUT');

%Set link data (can be used to react to events online)
Eyelink('Command', 'link_event_filter = LEFT,FIXATION,SACCADE,BLINK,MESSAGE,FIXUPDATE,INPUT');
Eyelink('Command', 'link_sample_data  = LEFT,GAZE,GAZERES,HREF,PUPIL,AREA,STATUS,INPUT');
    
Eyelink('Command', 'record_status_message "Start recording"');
Eyelink('Message', 'START RECORDING...');
Eyelink('StartRecording', [], [], [], 1);

end

%% Start Experiment

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% Setup MEG and Play Story
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Change folder to SaveFolder
cd (folder.Savefolder);

%MEG setup
PTBSetupExperiment('MEGBound_Task'); 
    
if isMEG==1
    PTBInitStimTracker;
    collection_type = 'Char';
    PTBSetInputCollection(collection_type);
    PTBSetInputDevice(button_box_id);   
end

%Trigger to eyelink for instructions
if eye.record_eye == 1
   Eyelink('Command', 'record_status_message "Instructions diplayed..."'); %message to experimenter
   Eyelink('Message', 'LISTENINSTR'); %instructions to listen to the story
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% Display Initial Instructions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
PTBTextSize = stim.textSize; 
PTBDisplayParagraph({'In this session, you will listen to a story approximately 12 minutes in length.', ... 
    'We ask that you pay close attention to the story.', ...
    'After listening to the story, you will asked to provide a detailed recollection of the story:', ...
    'Your recollection will be scored based on accuracy for the recollection of the story.', ...
    'Please keep looking at the cross throughout the experiment.', ...
    'Push the button to start the story.'},...
            {'center', stim.textSpace}, {'any'});

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% Play Story 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Get .wav file duration
[y, freq] = audioread([folderIn wav_file]);
wavedata = y';
stim.duration = size(wavedata,2) / freq;        

if stim.skip_story == 0  
    %Generate fixation and play story
    PTBTextSize = stim.fixCrossSize; 
    PTBDisplayParagraph({'+'},{'center', stim.textSpace},{stim.duration});
    PTBPlaySoundFile([folderIn wav_file],{'end'}, trig.values);
    
    %Trigger to eyelink for story
    if eye.record_eye == 1
       Eyelink('Command', 'record_status_message "Story begins..."'); %message to experimenter
       Eyelink('Message', 'SSTORY'); %start of story
    end

    %Store story onset
    StoryOnset = PTBLastPresentationTime;

    WaitSecs(stim.duration)

%If we want to try stuff without story
elseif stim.skip_story == 1
    %Generate fixation and play story
    PTBTextSize = stim.fixCrossSize; 
    PTBDisplayParagraph({'+'},{'center', stim.textSpace},{stim.duration});
    PTBPlaySoundFile([folderIn wav_file],{'end'});
    WaitSecs(1);
    KbWait;
end

%Trigger to eyelink for story
if eye.record_eye == 1
   Eyelink('Command', 'record_status_message "Story ends..."'); %message to experimenter
   Eyelink('Message', 'ESTORY'); %end of story
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% Start Capture
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Start recording
PsychPortAudio('GetAudioData', parec, rec.duration, rec.max, rec.min); %Sound inputbuffer prepared/allocated for capture
PsychPortAudio('Start', parec, rec.repetitions, rec.when, rec.waitForStart); %Start audio capture immediately and wait for the capture to start.

%Empty matrices used later
rec.recalling = []; 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% Display Recall Instructions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Trigger to eyelink for instructions
if eye.record_eye == 1
   Eyelink('Command', 'record_status_message "Instructions for recalling diplayed..."'); %message to experimenter
   Eyelink('Message', 'RECALLINSTR'); %instructions to record recalling the story
end

%Instructions
PTBTextSize = stim.textSize; 
PTBDisplayParagraph({'You have now reached the end of the story!', ... 
    'Now, we ask that you summarize the story from start to finish.', ...
    'Your recording can be as long as you wish.', ...
    'Please speak aloud, do not whisper.', ...
    'It is very important that you keep your head still.',...
    'Push the button to start recording.',...
    'To end the recording, push the button twice.'...
    'Please start talking as soon as you see the fixation cross.'}, ...
            {'center', stim.textSpace}, {'any'}, trig.values);

%Store recall onset
RecallOnset = PTBLastKeyPress;

%Empties the buffer before recalling
PsychPortAudio('GetAudioData', parec); 

%Fixation cross white
PTBTextSize = stim.fixCrossSize; 
PTBDisplayParagraph({'+'},{'center', stim.textSpace}, {stim.duration}, trig.values); 
fprintf('>>>>> Recording has started, boom!\n'); %indicates to the experimenter that recording has started

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% Recalling
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Trigger to eyelink for story
if eye.record_eye == 1
   Eyelink('Command', 'record_status_message "Recalling begins..."'); %message to experimenter
   Eyelink('Message', 'SRECALL'); %start of recalling
end 
    
%Little loop to makes sure that participants don't just press the key by
%mistake but keeps it presses
%initialise
PTBTextSize = stim.fixCrossSize; 
keyid_all = [];

while sum(keyid_all) < stim.ntimespressed % we do care only about multiple responses 
    WaitSecs(0.2);
    PTBDisplayParagraph({'+'},{'center', stim.textSpace}, {'any'}); %waits for input
    keypressed = 1;
    keyid_all = [keypressed, keyid_all]; %stacks keycodes
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% Record Recollection and quit capture
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Store the recalling audiodata 
rec.recalling = PsychPortAudio('GetAudioData', parec);%, rec.duration, rec.max, rec.min); 
%Store recorded sound to wavfile
audiowrite(fullfile(folder.Savefolder, sprintf('S%s_recallStory%sReader%s_%s%s%s', num2str(SubjectNumber), num2str(folder.iStory), folder.reader, datestr(now, 'mmddyy_HHMM'), '.wav')), transpose(rec.recalling), rec.freq);

%Stop capture:
PsychPortAudio('Stop', parec);
%Close the audio device:
PsychPortAudio('Close', parec);

%Trigger to eyelink for story
if eye.record_eye == 1
   Eyelink('Command', 'record_status_message "Recalling ends..."'); %message to experimenter
   Eyelink('Message', 'ERECALL'); %start of recalling
end  

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% End experiment
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Display recording text
PTBTextSize = stim.textSize; 
PTBDisplayParagraph({'End of this story!'}, {'center', stim.textSpace}, {'any'}, trig.values);

%Trigger to eyelink for story
if eye.record_eye == 1
   Eyelink('Command', 'record_status_message "Stop recording"'); %message to experimenter
   Eyelink('Message', 'STOP'); %start of recalling
   Eyelink('StopRecording');
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% Save data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Store story ID
stim.TaskDataFile{2,1}= iStory;

%Store reader name
if Reader == 1
    stim.TaskDataFile{2,2}= {'Samantha'};
else
    stim.TaskDataFile{2,2}= {'Michael'};
end

%Store reader name
stim.TaskDataFile{2,3}= 1;
stim.TaskDataFile{2,4}= RecallOnset;

%Save file to data folder
save('params', 'trig', 'stim', 'rec', 'folder')

%And finish up
if eye.record_eye == 1
   if eye.online      
   %Stop writing to edf
   disp('Stop Eyelink recording...')
   Eyelink('Command', 'set_idle_mode');  
   WaitSecs(0.5);
   Eyelink('CloseFile');     
   %Shut down connection
   Eyelink('Shutdown'); 
   end
end

%PTBDisplayBlank({.1},'');
PTBCleanupExperiment;

clear Screen; %exits debug mode

cd (fullfile(folder.mainFolder, '/', folder.expFolder));

