%% simulink_init_setup.m  (v2 - fixes undersampling bug)
% Run this ONCE before opening/running the Simulink model.
%
% WHAT CHANGED FROM v1 AND WHY:
% The LDR flash pattern toggles every 0.5 simulated seconds. v1 used
% dt = 1 second between samples -- too slow to ever see the toggle
% (classic aliasing: sampling slower than the thing you're watching
% makes it look constant). Now dt = 0.1s, so we check 10x per second,
% comfortably fast enough to catch a 0.5s flash.
%
% Because dt changed, every "how many ticks" number below is now
% seconds/dt instead of just seconds -- ticks and seconds are no
% longer the same number.

clear; clc;

%% --- Shared tuning parameters ---
dt             = Simulink.Parameter(0.1);   % seconds per simulation step (was 1)
WINDOW_SEC     = 3;                          % still "look back 3 seconds"
WINDOW_TICKS   = Simulink.Parameter(round(WINDOW_SEC/dt.Value));   % now 30, was 3
TRANSITION_THRESH = Simulink.Parameter(4);   % unchanged -- a real 0.5s flash
                                              % gives ~6 transitions in a
                                              % 3-second window, comfortably above 4
COOLDOWN_SEC   = 4*3600;                     % still "4 real hours"
COOLDOWN_TICKS = Simulink.Parameter(round(COOLDOWN_SEC/dt.Value)); % now 144000, was 14400

%% --- Synthetic LDR signal ---
sim_seconds = 6*3600;
t  = (0:dt.Value:sim_seconds)';
N  = length(t);
LDR = zeros(N,1);
flash_start_tick = round(2*3600/dt.Value);   % now 72000, was 7200

for i = 1:N
    if i < flash_start_tick
        LDR(i) = 1;
    else
        LDR(i) = mod(floor(t(i)/0.5), 2);
    end
end

ldr_ts = timeseries(LDR, t, 'Name', 'LDR');

fprintf('Workspace ready: ldr_ts (%d samples)\n', N);
fprintf('dt=%.2f  WINDOW_TICKS=%d  TRANSITION_THRESH=%d  COOLDOWN_TICKS=%d\n', ...
    dt.Value, WINDOW_TICKS.Value, TRANSITION_THRESH.Value, COOLDOWN_TICKS.Value);

%% --- Reference: updated MATLAB Function block code ---
% Paste this into the "transitionCounter" block, replacing the old
% version -- the buffer size must match the new WINDOW_TICKS (30, not 3).
%
%   function transitions = transitionCounter(ldr_sample)
%       persistent buffer
%       if isempty(buffer)
%           buffer = zeros(1, 30);   % 30 = WINDOW_TICKS at dt=0.1s
%       end
%       buffer = [buffer(2:end), ldr_sample];
%       transitions = sum(abs(diff(buffer)));
%   end