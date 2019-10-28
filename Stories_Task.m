function [] = Stories_Task(SubjectNumber, iStory, Reader, is_debugging, isMEG)

%%
% NyU STOries (NUTSO) MEG Task Code
% Last edited by Omri Raccah (October, 2019)
% Reader (0) = Michael, Reader (1) = Samantha

% 10/09/19: Edited by Arianna Zuanazzi: added voice recording for story
% recall and changed names of variables to save them into structures

%% checks
questdlg('Turn off exhaust fan!');

%% param to skip story

stim.skip_story = 0; %want to skip the story for debugging?
%stim.storyOrder = inputdlg('Stories order?');

%% Set base directory 

folder.mainFolder = '/Users/megadmin/Desktop/Experiments/Omri';
cd (folder.mainFolder);

folder.expFolder = 'Stories_Project-master';

% Initialize subject string
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

stim.ntimespressed = 2;% secs for keypress for end recalling part
stim.white = [255 255 255];
stim.gray = [128 128 128];
stim.green = [0 200 0];
stim.textSize = 25;
stim.textSpace = 15;
stim.fixCrossSize = 60;

% define PTB global variables % WHAT DOES THIS ERROR MEAN
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

% set screen params
Screen('Preference', 'SkipSyncTests', 1);
%screen number and open window
%screen.number = max(Screen('Screens'));
%screen.window = 10; %taken from [screen.window] = Screen('OpenWindow', screen.number)
%[screen.cx, screen.cy] = RectCenter([0 0 1024 768]); %projector parameters for screen
% set text color
PTBTextColor = stim.white;
% set text size	
PTBTextSize = stim.textSize; 
% set background color
PTBSetBackgroundColor(stim.gray);
% set text font	
PTBSetTextFont('Arial'); 	
% ensure up-to-date PTB version
PTBVersionCheck(1,1,5,'at least');
% set PTB to debugging mode
PTBSetIsDebugging(is_debugging);
% "q" key press will quit the program
PTBSetExitKey('q'); 
button_box_id = 1; % pointer to MEG button box
% Initialize trigger values
trig.values = [1]; 

%% Initialize audio recording  

% Sound sampling frequency
rec.freq = 48000;

% Sound volume level and voice threshold
stim.audio.vol = 0.6; %stimulus volume
rec.threshold = 0.07; %threshold to record voice
rec.duration = 600; %duration of recording
rec.repetitions = 0; %0:infinite repetitions, ie.,until manually stopped via the ‘Stop’ subfunction
rec.when = 0; %starttime of playback: 0: immediately
rec.waitForStart = 1; %wait for sound onset?
rec.max = []; %max amount of recorded data (optional)
rec.min = []; %min amount of recorded data (optional)

% Initialize PsychPortAudio sound driver: 
stim.audio.latLev = 1; %Set low level latency mode with compensation for hardware's inherent latency 
InitializePsychSound(stim.audio.latLev);
% PsychPortAudio('GetDevices')

% Open sound device for recording
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

% load story read by male speaker
if Reader == 0
    
    folderIn = [folder.basedir, '/', 'Story_AudioFiles/Michael/'];
    
elseif Reader == 1
   
     folderIn = [folder.basedir, '/', 'Story_AudioFiles/Samantha/'];
    
end

wav_file = ['s', num2str(iStory), '.wav'];

%% INITIATE ENCODING OUTPUT DATA [MATRIX WITH MY ENCODING DATA]

StoryDataFile = cell(2,4);
StoryDataFile{1,1} = 'Story_Number'; % trial number out of 30
StoryDataFile{1,2} = 'Reader'; % The file name for the word
StoryDataFile{1,3} = 'Story_OnsetTime'; % time of stim onset relative to task-onset
StoryDataFile{1,4} = 'Recollection_OnsetTime'; % time of stim onset relative to task-onset

% flush key events: ensures that Last[Key/Presentation]Time functions work as expected
FlushEvents('keyDown')

%% Start Experiment

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% Setup MEG and Play Story
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% change folder to SaveFolder
cd (folder.Savefolder);

% MEG setup
PTBSetupExperiment('MEGBound_Task'); 
    
if isMEG==1
    
    PTBInitStimTracker;
    collection_type = 'Char';
    PTBSetInputCollection(collection_type);
    PTBSetInputDevice(button_box_id);
    
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

% get .wav file duration
[y, freq] = audioread([folderIn wav_file]);
wavedata = y';
stim.duration = size(wavedata,2) / freq;        

if stim.skip_story == 0
    
    % generate fixation and play story
    PTBTextSize = stim.fixCrossSize; 
    PTBDisplayParagraph({'+'},{'center', stim.textSpace},{stim.duration});
    PTBPlaySoundFile([folderIn wav_file],{'end'}, trig.values);

    % store story onset
    StoryOnset = PTBLastPresentationTime;

    WaitSecs(stim.duration)

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% Start Capture
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Start recording
PsychPortAudio('GetAudioData', parec, rec.duration, rec.max, rec.min); %Sound inputbuffer prepared/allocated for capture
PsychPortAudio('Start', parec, rec.repetitions, rec.when, rec.waitForStart); %Start audio capture immediately and wait for the capture to start.

%Empties matrices used later
rec.recalling = []; 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% Display Recall Instructions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Instructions
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

% store recall onset
RecallOnset = PTBLastKeyPress;

% Empties the buffer before recalling
PsychPortAudio('GetAudioData', parec); 

% Fixation cross white
PTBTextSize = stim.fixCrossSize; 
PTBDisplayParagraph({'+'},{'center', stim.textSpace}, {stim.duration}, trig.values); 
fprintf('>>>>> Recording has started, boom!\n'); %indicates to the experimenter that recording has started

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% Recalling
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% Little loop to makes sure that participants don't just press the key by
% mistake but keeps it presses
% initialise
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

%stores the recalling audiodata 
rec.recalling = PsychPortAudio('GetAudioData', parec);%, rec.duration, rec.max, rec.min); 
% Store recorded sound to wavfile
audiowrite(fullfile(folder.Savefolder, sprintf('S%s_recallStory%sReader%s_%s%s%s', num2str(SubjectNumber), num2str(folder.iStory), folder.reader, datestr(now, 'mmddyy_HHMM'), '.wav')), transpose(rec.recalling), rec.freq);

% Stop capture:
PsychPortAudio('Stop', parec);
% Close the audio device:
PsychPortAudio('Close', parec);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% End experiment
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% display recording text
PTBTextSize = stim.textSize; 
PTBDisplayParagraph({'End of this story!'}, {'center', stim.textSpace}, {2}, trig.values);
        
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% Save data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% store story ID
stim.TaskDataFile{2,1}= iStory;

% store reader name
if Reader == 1
    stim.TaskDataFile{2,2}= {'Samantha'};
else
    stim.TaskDataFile{2,2}= {'Michael'};
end

% store reader name
stim.TaskDataFile{2,3}= 1;
stim.TaskDataFile{2,4}= RecallOnset;

% save file to data folder
save('params', 'trig', 'stim', 'rec', 'folder')

%And finish up
%PTBDisplayBlank({.1},'');
PTBCleanupExperiment;

clear Screen; %exits debug mode

cd (fullfile(folder.mainFolder, '/', folder.expFolder));

