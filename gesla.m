classdef gesla
    methods(Static)

        % These scripts read in data to matlab - for faster speeds, use in memory data functions (e.g. arrayDatastore())

        function data = load_site(file,path,flag_removal)
            % Function to load data in GESLA-3 files
            % INPUT: 
            %    file -> string scalar or array with name/s of the individual file/s in GESLA format
            %    path -> directory to where the GESLA data files are kept
            %    flag_removal - > 1 for removing wrong values, 2 for removing NULL
            %    values, [1, 2] for removing both
            %
            % OUTPUT, struct 'data' containing for each site:
            %    ts -> time in datetime 
            %    sl -> tide gauge sea level measurements (with or w/o flag corrections)
            %    f1 -> flag - column 4
            %    f2 -> flag - column 5
            %    lat -> latitude
            %    lon -> longitude
            % 
            % Removes wrong values as defined in metadata
            % Removes NULL values as defined in metadata
            %... Marta Marcos and Ivan Haigh, September 2021... Amended Luke Jenkins, May 2022...
            
            headerlength = 41;
            data = struct();
        
            if endsWith(path,'\') || endsWith(path,'/')
                q = '';
            elseif contains(path,'\') && ~endsWith(path,'\')
                q = '\';
            elseif contains(path,'/') && ~endsWith(path,'/')
                q = '/';
            end
        
            if ischar(file)
                file = strtrim(string(file));
            end
        
            if ~isrow(file)
                file = file';
            end
        
            for i = file
            
                %...Import data
                A = importdata(strcat(path,q,i),' ',headerlength);
        
                %...Transform time to datetime format
                dt = datetime(A.textdata(headerlength+1:end,1),'InputFormat','yyyy/MM/dd')+...
                    duration(A.textdata(headerlength+1:end,2),'InputFormat','hh:mm:ss');
        
                %...Read sea level observations 
                sl=A.data(:,1);
        
                % remove incorrect values (according to flag in column 5)
                f1 = A.data(:,2);
                f2 = A.data(:,3);
                if length(flag_removal) == 1
                    switch flag_removal
                        case 1
                            sl(f1 == 0) = NaN;
                        case 2
                            sl(f2 == 0) = NaN;
                    end
                elseif length(flag_removal) > 1
                    sl(f1 == 0) = NaN;
                    sl(f2 == 0) = NaN;   
                end     
        
                %...Read lat & lon
                lat = str2double(extractAfter(A.textdata(~cellfun(@isempty,cellfun(@(x)strfind(x,'LATITUDE'),...
                    A.textdata(1:headerlength,1),'UniformOutput',0)),1),'# LATITUDE'));
        
                lon = str2double(extractAfter(A.textdata(~cellfun(@isempty,cellfun(@(x)strfind(x,'LONGITUDE'),...
                    A.textdata(1:headerlength,1),'UniformOutput',0)),1),'# LONGITUDE'));
                
                data.(strrep(i,'-','_')).ts = dt; 
                data.(strrep(i,'-','_')).sl = sl; 
                data.(strrep(i,'-','_')).f1 = f1; 
                data.(strrep(i,'-','_')).f2 = f2; 
                data.(strrep(i,'-','_')).lat = lat; 
                data.(strrep(i,'-','_')).lon = lon;
        
            end
            
        end

        function filenames = site_to_file(metadata,site_names)
            % Function to get the name/s of GESLA files from the site name/s 
            % INPUT: 
            %    metadata -> path to the metadata 'GESLA3_ALL.csv'
            %    site_names -> name of individual site (string) or multiple sites (string array) 
            % OUTPUT:
            %    file_names -> name of individual file (string scalar) or multiple files (string array) 
        
            %... Luke Jenkins, May 2022...
            
            d = readtable(metadata);
            
            filenames = string(d.FILENAME(contains(d.SITENAME,site_names)));
            
            if isempty(filenames) % no sites found
                error(['No file name found for site name: ',char(site_names)])
                
            elseif ~isStringScalar(filenames)
                prompt = {strcat("-Site: ",string(d.SITENAME(contains(d.FILENAME,filenames))), " -Country: ",...
                    string(d.COUNTRY(contains(d.FILENAME,filenames))), " -File: ",filenames)};
                dlgtitle = "Multiple files found: Select which file names you wish to output (Place '1' in dialogue box)";
                answer = inputdlg(prompt{:},dlgtitle,[1 length(char(dlgtitle))+15]);
                filenames = filenames(~cellfun(@isempty, answer));
        
            end
        
        end

        function data = load_bbox(bounding_box,path,metadata,flag_removal)
            % Function to load data in GESLA-3 files from within lat/lon bounding box
            % INPUT: 
            %    bounding_box -> [northern extent, southern extent, western extent, eastern extent]
            %    path -> directory to where the GESLA data files are kept
            %    metadata -> directory and filename for the metadata
            %    flag_removal - > 1 for removing wrong values, 2 for removing NULL
            %    values, [1, 2] for removing both
            %
            % OUTPUT, struct 'data' containing for each site:
            %    ts -> time in datetime 
            %    sl -> tide gauge sea level measurements (with or w/o flag corrections)
            %    f1 -> flag - column 4
            %    f2 -> flag - column 5
            %    lat -> latitude
            %    lon -> longitude
            % 
            % Removes wrong values as defined in metadata
            % Removes NULL values as defined in metadata
            %... Luke Jenkins, May 2022
        
            md = readtable(metadata);

            filenames = string(md.FILENAME((md.LATITUDE >= bounding_box(2)  &  md.LATITUDE <= bounding_box(1)) &...
                (md.LONGITUDE >= bounding_box(3)  &  md.LONGITUDE <= bounding_box(4))));
        
            data = gesla.load_site(filenames,path,flag_removal);
        
        end

        function data = load_nearest(coords,n,path,metadata,flag_removal)
            % Function to load data in GESLA-3 files with nearest lat/lon to given coordinates in *Euclidean distance*
            % INPUT: 
            %    coords -> coordinates to use (lon,lat)
            %    n -> number of nearest sites to select
            %    path -> directory to where the GESLA data files are kept
            %    metadata -> directory and filename for the metadata
            %    flag_removal - > 1 for removing wrong values, 2 for removing NULL
            %    values, [1, 2] for removing both
            %
            % OUTPUT, struct 'data' containing for each site:
            %    ts -> time in datetime 
            %    sl -> tide gauge sea level measurements (with or w/o flag corrections)
            %    f1 -> flag - column 4
            %    f2 -> flag - column 5
            %    lat -> latitude
            %    lon -> longitude
            % 
            % Removes wrong values as defined in metadata
            % Removes NULL values as defined in metadata
            %... Luke Jenkins, May 2022
        
            md = readtable(metadata);

            scoords = [md.LONGITUDE md.LATITUDE];
            i = knnsearch(scoords,[-60 10],'K',n,'IncludeTies',true);

            filenames = string(md.FILENAME(i));
        
            data = gesla.load_site(filenames,path,flag_removal);
        
        end

    end

end




