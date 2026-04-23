hotkey('x', 'escape_screen(); assignin(''caller'',''continue_'',false);');

idle(1000);

bhv_variable('numeric_empty',[]);
bhv_variable('char_empty','');

% str = ["Mercury" "Gemini" "Apollo"; "Skylab" "Skylab B" "ISS"];
% bhv_variable('string',str);
% bhv_variable('string_scalar',string);
% bhv_variable('string_empty',repmat(string,0,0));

DateStrings = {'2014-05-26';'2014-08-03'};
t = datetime(DateStrings,'InputFormat','yyyy-MM-dd');
bhv_variable('datetime',t);
bhv_variable('datetime_scalar',datetime);
bhv_variable('datetime_empty',repmat(datetime,0,0));

D = duration(1,30:33,0);
bhv_variable('duration',D);
bhv_variable('duration_scalar',duration);
bhv_variable('duration_empty',repmat(duration,0,0));

D = [1 3;4 2];
T = hours([1 2; 25 12]);
L = calendarDuration(1,13,D,T);
bhv_variable('calendarDuration',L);
bhv_variable('calendarDuration_scalar',calendarDuration);
bhv_variable('calendarDuration_empty',repmat(calendarDuration,0,0));

A = [1 3 2; 2 1 3; 3 1 2];
B = categorical(A,[1 2 3],{'red' 'green' 'blue'});
bhv_variable('categorical',B);
bhv_variable('categorical_empty',categorical);

LastName = {'Sanchez';'Johnson';'Li';'Diaz';'Brown'};
Age = [38;43;38;40;49];
Smoker = logical([1;0;1;0;1]);
Height = [71;69;64;67;64];
Weight = [176;163;131;133;119];
BloodPressure = [124 93; 109 77; 125 83; 117 75; 122 80];
T = table(LastName,Age,Smoker,Height,Weight,BloodPressure);
if ~verLessThan('matlab','9.5')
    T = addprop(T,'custom1','table');
    T = addprop(T,'custom2','variable');
    T.Properties.CustomProperties.custom1 = 'This is a table property.';
    T.Properties.CustomProperties.custom2 = {'These' 'is' 'a' 'variable' 'properties' '.'};
end
bhv_variable('table',T);
bhv_variable('table_empty',table);

if ~verLessThan('matlab','9.1')
    MeasurementTime = datetime({'2015-12-18 08:03:05';'2015-12-18 10:03:17';'2015-12-18 12:03:13'});
    Temp = [37.3;39.1;42.3];
    Pressure = [30.1;30.03;29.9];
    WindSpeed = [13.4;6.5;7.3];
    TT = timetable(MeasurementTime,Temp,Pressure,WindSpeed);
    if ~verLessThan('matlab','9.5')
        TT = addprop(TT,'custom1','table');
        TT = addprop(TT,'custom2','variable');
        TT.Properties.CustomProperties.custom1 = 'This is a table property.';
        TT.Properties.CustomProperties.custom2 = {'These' 'are' 'variable properties'};
    end
    bhv_variable('timetable',TT);
    TT_e = timetable;
    TT_e = addprop(TT_e,'test','table');
    bhv_variable('timetable_empty',TT_e);
end

field = 'f';
value = {'some text'; [10, 20, 30]; magic(5)};
s = struct(field,value);
bhv_variable('struct',s);
bhv_variable('struct_scalar',struct);
bhv_variable('struct_empty',repmat(struct,0,0));

C = {1,2,3; 'text',magic(5),{11; 22; 33}};
bhv_variable('cell',C);
bhv_variable('cell_empty',{});

f = @(x,y) (x.^2 - y.^2);
bhv_variable('function_handle',f);

keySet = {'Jan','Feb','Mar','Apr'};
valueSet = [327.2 368.2 197.6 178.4];
M = containers.Map(keySet,valueSet);
bhv_variable('Map',M);
bhv_variable('Map_scalar',containers.Map);

ts1 = timeseries([1.1 2.9 3.7 4.0 3.0]',1:5,...
'Name','Acceleration');
ts2 = timeseries([3.2 4.2 6.2 8.5 1.1]',1:5,...
'Name','Speed');
ts = tscollection({ts1;ts2});
bhv_variable('timeseries',repmat(ts1,2,2));
bhv_variable('timeseries_scalar',timeseries);
bhv_variable('timeseries_empty',repmat(timeseries,0,0));
bhv_variable('tscollection',ts);
bhv_variable('tscollection_scalar',tscollection);
