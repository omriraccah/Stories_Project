function [] = Stories_Task(SubjectNumber,iStory, Reader,is_debugging,isMEG)

%%
% NyU STOries (NUTSO) MEG Task Code
% Last edited by Omri Raccah (October, 2019)
% Reader (0) = Michael, Reader (1) = Samantha

%% Set base directory 

basedir = '/Users/omriraccah/Documents/Projects/Naturalistic_Stories_Project/StoryTask/';

%% Initialize subject string

if SubjectNumber < 10
    SubjStr = ['S0' num2str(SubjectNumber)];
else
    SubjStr = ['S', num2str(SubjectNumber)];
end

%% Initialize task vars

% define PTB global variables 
global PTBTextSize;
global PTBTextColor;
global PTBLastKeyPress;
global PTBLastPresentationTime;

% set screen params
Screen('Preference', 'SkipSyncTests', 1);
% set text color
PTBTextColor = [255 255 255];
% set text size	
PTBTextSize = 20; 
% set background color
PTBSetBackgroundColor([128 128 128]);
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
trig = [1 2 4 8 16 32 64 128];

%% Set keyboard parameters

%get the devices attached
[a b] = GetKeyboardIndices;

%find the button box index and pass it to kbcheck so that kbcheck only listens
%for the button box
BBidx = a(strmatch('904',b));

%% Store speaker path and audiofile name

% load story read by male speaker
if Reader == 0
    
    folderIn = [basedir, 'Story_AudioFiles/Michael/'];
    
elseif Reader == 1
   
     folderIn = [basedir, 'Story_AudioFiles/Samantha/'];
    
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
%%%%%%% Setup Experiment
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

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

PTBDisplayParagraph({'In this session, you will listen to a story approximately 12 minutes in length.', ... 
    'We ask that you pay close attention to the story.', ...
    'After listening to the story, you will asked to provide a detailed recollection of the story.', ...
    'Your recollection will be scored based on accuracy for the events in the story', ...
    'Please keep your eyes fixed on the cross throughout the experiment', ...
    'Push any button to start the story'},...
            {'center', 30}, {2});
        
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% Play Story 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% get .wav file duration
[y, freq] = audioread([folderIn wav_file]);
wavedata = y';
duration = size(wavedata,2) / freq;        

% generate fixation and play story
PTBDisplayParagraph({'+'},{'center', 60},{duration});
PTBPlaySoundFile([folderIn wav_file],{'end'});

% store story onset
StoryOnset = PTBLastPresentationTime;

WaitSecs(duration)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% Display Recall Instructions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

PTBDisplayParagraph({'You have now reached the end of the story!', ... 
    'Next, we ask that you summarize the story from start to finish.', ...
    'Your recording should be as long as you wish.', ...
    'Please push any button to start recording.'},...
            {'center', 30}, {'any'});

% store recall onset
RecallOnset = PTBLastKeyPress;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%% Record Recollection
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% display recording text
PTBDisplayParagraph('You are now recording your summary of the story.', ...
    'Please push to end the recording.',{'center'},{'any'});

%% Save data and write to subject-specific file

% store story ID
TaskDataFile{2,1}= iStory;

% store reader name
if Reader == 1
    TaskDataFile{2,2}= {'Samantha'};
else
    TaskDataFile{2,2}= {'Michael'};
end

% store reader name
TaskDataFile{2,3}= StoryOnset;
TaskDataFile{2,4}= RecallOnset;

% save file to data folder
save([basedir 'TaskData/StoryDataFileSub' SubjStr 'Story' num2str(iBlock) '.mat'],'StoryDataFileSub')

