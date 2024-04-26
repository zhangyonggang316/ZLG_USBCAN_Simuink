classdef (StrictDefaults) ZLG_USBCANFrom < matlab.System
    %周立功 USBCAN-Ⅱ接收模块
    %
    % This template includes most, but not all, possible properties, attributes,
    % and methods that you can implement for a System object in Simulink.

    % Public, tunable properties
    properties
        DeviceType (1, 1) {mustBePositive, mustBeInteger} = 4;
        DeviceInd  = 0;
        ID = 0x00000000;
        BaudRate = 250;
        
    end

    properties (Nontunable)
        OutputBusName = 'CAN_MESSAGE_BUS';
        
    end

    % Public, non-tunable properties

    properties (DiscreteState)
    end

    % Pre-computed constants
    properties (Access = private)
        InitConfig;
        BoardInfo;
        CanObj;

    end

    methods
        % Constructor
        function obj = ZLG_USBCANFromFrom(varargin)
            % Support name-value pair arguments when constructing object
            setProperties(obj,nargin,varargin{:})
        end
    end

    methods (Access = protected)
        %% Common functions
        function setupImpl(obj)
            % Perform one-time calculations, such as computing constants


            %% create data struct
            obj.InitConfig = struct("AccCode",0x0,"AccMask",0xFFFFFFFF,"Reserved",0,"Filter",1,"Timing0",0x01,"Timing1",0x1c,"Mode",0x0);
            
            obj.BoardInfo = struct("hw_Version",0x0,"fw_Version",0,"dr_Version",0,"in_Version",0,"irq_Num",0,"can_Num",0,"str_Serial_Num",zeros(1,20),"str_hw_Type",zeros(1,40),"Reserved",zeros(1,4));

            obj.CanObj = struct("ID",0x0100,"TimeStamp",0,"TimeFlag",0,"SendType",0,"RemoteFlag",0,"ExternFlag",0,"DataLen",8,"Data",zeros(1,8),"Reserved",zeros(1,3));

            %IndicateLight = libpointer("");

            disp("Create data successful");

            % config ID for filter
            if obj.ID ~=0 && isnumeric(obj.ID)
               ShiftID = bitshift(obj.ID,3);
               obj.InitConfig.AccCode = ShiftID;
               obj.InitConfig.AccMask = 7;

            end

            % config baud rate
            switch obj.BaudRate
                case 250
                  % use default value
                case 500
                    obj.InitConfig.Timing0 = 0x00;
                    obj.InitConfig.Timing1 = 0x1C;
                case 1000
                    obj.InitConfig.Timing0 = 0x00;
                    obj.InitConfig.Timing1 = 0x14;                   
            end


            %% load and open CanDevice
            if ~libisloaded("ControlCAN")
                loadlibrary ControlCAN ControlCAN.h;
                disp("# load ControlCAN.dll #");

                isOpen = calllib('ControlCAN','VCI_OpenDevice',obj.DeviceType,0,0);
                if isOpen
                    disp("# CAN open successful #");
                else
                    warning("CAN open faulse");
                end

                %% Init can device; display can config
                [a,b] = calllib('ControlCAN','VCI_InitCAN',obj.DeviceType,0,0,obj.InitConfig);

                if a
                    disp("# InitConfig successfull #");
                    disp(b);
                else
                    warning("InitConfig faulse");
                end

                %% display can deviece info
                [a1,b1] = calllib('ControlCAN','VCI_ReadBoardInfo',obj.DeviceType,0,obj.BoardInfo);
                if a1
                    disp("# InitConfig successfull #");
                    disp(b1);
                else
                    warning("BoardInfo warning");
                end

                %% star can device
                a2 = calllib('ControlCAN','VCI_StartCAN',obj.DeviceType,0,0);
                if a2
                    disp("# star successfull #");
                else
                    warning("star warning");
                end
            end


        end

        function [can_R] = stepImpl(obj)
            % Implement algorithm. Calculate y as a function of input u and
            
            [a2,obj.CanObj]= calllib('ControlCAN','VCI_Receive',obj.DeviceType,0,0,obj.CanObj,1,40);
            
            can_R.Extended = uint8(obj.CanObj.ExternFlag);
            can_R.Length = uint8(obj.CanObj.DataLen);
            can_R.Remote = uint8(obj.CanObj.RemoteFlag);
            can_R.Error = uint8(0);
            can_R.ID = uint32(obj.CanObj.ID);
            can_R.Timestamp = obj.CanObj.TimeStamp;
            can_R.Data = uint8(obj.CanObj.Data);

            
            calllib('ControlCAN','VCI_ClearBuffer',obj.DeviceType,0,0);
           
        end

        function resetImpl(obj)
            % Initialize / reset discrete-state properties

            disp("# reset discrete-state #");




        end

        function releaseImpl(obj)
            % Release resources, such as file handles
            if libisloaded("ControlCAN")
                calllib('ControlCAN','VCI_CloseDevice',obj.DeviceType,0);
                disp("# Close ControlCAN #");
                unloadlibrary ControlCAN;
                disp("# unload ControlCAN #");
            end
        end

        %% Backup/restore functions
        function s = saveObjectImpl(obj)
            % Set properties in structure s to values in object obj

            % Set public properties and states
            s = saveObjectImpl@matlab.System(obj);

            % Set private and protected properties
            %s.myproperty = obj.myproperty;
        end

        function loadObjectImpl(obj,s,wasLocked)
            % Set properties in object obj to values in structure s

            % Set private and protected properties
            % obj.myproperty = s.myproperty; 

            % Set public properties and states
            loadObjectImpl@matlab.System(obj,s,wasLocked);
        end

        %% Simulink functions
        function ds = getDiscreteStateImpl(obj)
            % Return structure of properties with DiscreteState attribute
            ds = struct([]);
        end


        function out = getOutputDataTypeImpl(obj)
            out = obj.OutputBusName;
        end

        function out = isOutputComplexImpl(obj)
            % Return true for each output port with complex data
            out = false;

            % Example: inherit complexity from first input port
            % out = propagatedInputComplexity(obj,1);
        end

        function [out] = getOutputSizeImpl(obj)
            % Return size for each output port
            out = [1 1];

            % Example: inherit size from first input port
            % out = propagatedInputSize(obj,1);
        end

        function fixedout = isOutputFixedSizeImpl(~)
            fixedout = true;
        end


        function icon = getIconImpl(obj)
            % Define icon for System block
            icon = mfilename("class"); % Use class name
            % icon = "My System"; % Example: text icon
            % icon = ["My","System"]; % Example: multi-line text icon
            % icon = matlab.system.display.Icon("myicon.jpg"); % Example: image file icon
        end


    end

    methods (Static, Access = protected)
        %% Simulink customization functions
        function header = getHeaderImpl
            % Define header panel for System block dialog
            header = matlab.system.display.Header(mfilename("class"));
        end





        function simMode = getSimulateUsingImpl
            % Return only allowed simulation mode in System block dialog
            simMode = "Interpreted execution";
        end
    end
end
