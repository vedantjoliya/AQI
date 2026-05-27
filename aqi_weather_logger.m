%% =====================================================
%  REAL-TIME AQI SYSTEM (NO PREDICTION)
%  Raspberry Pi + Nova PM Sensor + Google Sheets
%% =====================================================

clear
clc
close all

%% ================= CONFIG =================

cfg.pi_ip   = '192.168.1.242';
cfg.username = 'admin';
cfg.password = 'thingspeak';

GOOGLE_SCRIPT_URL = "https://script.google.com/macros/s/AKfycbwCFsHIOQm6NtNWGTnqycblzjlO_37MD2owXSQn2zqjsidkYO0DLY6EkaFE8586AuHO4Q/exec";

%% ================= CONNECT PI =================

mypi = raspi(cfg.pi_ip, cfg.username, cfg.password);
sensor = serialdev(mypi,'/dev/ttyUSB0',9600);

disp("Raspberry Pi Connected")
pause(2)

%% ================= AQI FUNCTION =================

calcAQI = @(pm25, pm10) round(max(pm25*2, pm10*1.5));

%% ================= GOOGLE FUNCTION =================

sendToGoogle = @(payload) webwrite( ...
    GOOGLE_SCRIPT_URL, ...
    payload, ...
    weboptions('MediaType','application/json','Timeout',10));

%% ================= PLOT =================

figure('Name','Real-Time AQI','Color','w')
h = animatedline('Color','b','LineWidth',2);
grid on
xlabel('Time (sec)')
ylabel('AQI')
title('Live AQI Monitoring')

%% ================= MAIN LOOP =================

i = 0;
packetlength = 10;

disp("Real-time monitoring started...")

while true

    try

        data = read(sensor,packetlength,'uint8')';

        if length(data) >= 6 && data(1)==170 && data(2)==192

            i = i + 1;

            %% ---------- SENSOR VALUES ----------
            pm25_value = (double(data(4))*256 + double(data(3))) / 10;
            pm10_value = (double(data(6))*256 + double(data(5))) / 10;

            aqi_value = calcAQI(pm25_value, pm10_value);

            %% ---------- PLOT ----------
            addpoints(h,i,aqi_value);
            drawnow limitrate;

            fprintf("AQI: %d\n", aqi_value);

            %% ---------- SEND TO GOOGLE SHEETS ----------
            payload = struct();
            payload.Type = "CURRENT";
            payload.Time = datestr(now,'yyyy-mm-dd HH:MM:SS');
            payload.AQI = aqi_value;
            payload.PM25 = pm25_value;
            payload.PM10 = pm10_value;

            try
                sendToGoogle(payload);
                disp("Sent to Google Sheets");
            catch
                
            end

        end

    catch ME
        warning("Sensor error: %s", ME.message);
    end

    pause(1)

end