classdef gesla
    methods(Static)

        function data = load_file(file,path,gflag_removal,cflag_removal)
            % Function to load data in GESLA-3 files
            % INPUT: 
            %    file -> string scalar or array with name/s of the individual file/s in GESLA format
            %    path -> directory to where the GESLA data files are kept
            %    gflag_removal - > 'y' for removing values flagged by GESLA
            %    cflag_removal - > remove values by entering numbers that correspond to flags by the contributor (e.g., [2,4,5])
            %                      0 - no quality control
            %                      1 - correct value 
            %                      2 - interpolated value
            %                      3 - doubtful value
            %                      4 - isolated spike or wrong value
            %                      5 - missing value
            %
            % OUTPUT, struct 'data' containing for each site:
            %    ts -> time in datetime 
            %    sl -> tide gauge sea level measurements (with or w/o flag corrections)
            %    cont_fl -> flag - contributor flags
            %    gesla_fl -> flag - gesla checks, 0 = flagged value, 1 = correct value
            %    lat -> latitude
            %    lon -> longitude
            %    datum -> datum information
            %    gauge -> gauge type and information (e.g., 'bubbler - coastal')
            %    cont_fl_info -> flag information from the contributor to be used with cont_fl
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
                fid = fopen(strcat(path,q,i),'r');
                hd = cell(headerlength,1);
                for ih = 1:headerlength
                    hd(ih) = {fgetl(fid)};
                end
                d = textscan(fid,'%q %q %f %f %d');
                fclose(fid);
            
                %...Get datenum and datetime
                dt = datetime(d{:,1},'Format','yyyy/MM/dd');
                dt.Format = 'yyyy/MM/dd HH:mm:ss';
                dt = dt + timeofday(datetime(d{:,2},'Format','HH:mm:ss'));
                dn = datenum(dt);

                %...Read sea level observations 
                sl = cell2mat(d(3));
            
                % remove incorrect values (according to gesla flag)
                cont_fl = cell2mat(d(4));
                gesla_fl = cell2mat(d(5));
            
                if strcmp(gflag_removal, 'y')
                    sl(gesla_fl == 0) = NaN;
                end 
            
                % remove incorrect values (according to contributor flags)
                ii = ismember(cont_fl, cflag_removal);
                sl(ii) = NaN;
            
                %...Read lat & lon
                lat = str2double(extractAfter(hd(~cellfun(@isempty,cellfun(@(x)strfind(x,'LATITUDE'),...
                    hd,'UniformOutput',0)),1),'# LATITUDE'));
            
                lon = str2double(extractAfter(hd(~cellfun(@isempty,cellfun(@(x)strfind(x,'LONGITUDE'),...
                hd,'UniformOutput',0)),1),'# LONGITUDE'));
                
                %...Read metadata info
                datum = strtrim(string(extractAfter(hd(~cellfun(@isempty,cellfun(@(x)strfind(x,'DATUM INFORMATION'),...
                hd,'UniformOutput',0)),1),'# DATUM INFORMATION')));
            
                gauge = strcat(strtrim(string(extractAfter(hd(~cellfun(@isempty,cellfun(@(x)strfind(x,'INSTRUMENT'),...
                hd,'UniformOutput',0)),1),'# INSTRUMENT'))), " - ", ...
                    strtrim(string(extractAfter(hd(~cellfun(@isempty,cellfun(@(x)strfind(x,'GAUGE TYPE'),...
                hd,'UniformOutput',0)),1),'# GAUGE TYPE'))));
            
                cont_fl_info = string(hd(find(string(hd(1:headerlength,1)) ==...
                    '# Quality-control (QC) flags for column 4'):headerlength,1));

                data.(strrep(i,'-','_')).ts = dt; 
                data.(strrep(i,'-','_')).sl = sl; 
                data.(strrep(i,'-','_')).cont_fl = cont_fl; 
                data.(strrep(i,'-','_')).gesla_fl = gesla_fl; 
                data.(strrep(i,'-','_')).lat = lat; 
                data.(strrep(i,'-','_')).lon = lon;
                data.(strrep(i,'-','_')).datum = datum;
                data.(strrep(i,'-','_')).gauge = gauge;
                data.(strrep(i,'-','_')).cont_fl_info = cont_fl_info;
        
            end
            
        end

        function filenames = site_to_file(site_names,metadata)
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

        function data = load_bbox(bounding_box,path,metadata,gflag_removal,cflag_removal)
            % Function to load data in GESLA-3 files from within lat/lon bounding box
            % INPUT: 
            %    bounding_box -> [northern extent, southern extent, western extent, eastern extent]
            %    path -> directory to where the GESLA data files are kept
            %    metadata -> directory and filename for the metadata
            %    gflag_removal - > 'y' for removing values flagged by GESLA
            %    cflag_removal - > remove values by entering numbers that correspond to flags by the contributor (e.g., [2,4,5])
            %                      0 - no quality control
            %                      1 - correct value 
            %                      2 - interpolated value
            %                      3 - doubtful value
            %                      4 - isolated spike or wrong value
            %                      5 - missing value
            %
            % OUTPUT, struct 'data' containing for each site:
            %    ts -> time in datetime 
            %    sl -> tide gauge sea level measurements (with or w/o flag corrections)
            %    cont_fl -> flag - contributor flags
            %    gesla_fl -> flag - gesla checks, 0 = flagged value, 1 = correct value
            %    lat -> latitude
            %    lon -> longitude
            %    datum -> datum information
            %    gauge -> gauge type and information (e.g., 'bubbler - coastal')
            %    cont_fl_info -> flag information from the contributor to be used with cont_fl
            % 
            % Removes wrong values as defined in metadata
            % Removes NULL values as defined in metadata
            %... Luke Jenkins, May 2022
        
            md = readtable(metadata);

            filenames = string(md.FILENAME((md.LATITUDE >= bounding_box(2)  &  md.LATITUDE <= bounding_box(1)) &...
                (md.LONGITUDE >= bounding_box(3)  &  md.LONGITUDE <= bounding_box(4))));
        
            data = gesla.load_file(filenames,path,gflag_removal,cflag_removal);
        
        end

        function data = load_nearest(coords,n,path,metadata,gflag_removal,cflag_removal)
            % Function to load data in GESLA-3 files with nearest lat/lon to given coordinates in *Euclidean distance*
            % INPUT: 
            %    coords -> coordinates to use (lon,lat)
            %    n -> number of nearest sites to select
            %    path -> directory to where the GESLA data files are kept
            %    metadata -> directory and filename for the metadata
            %    gflag_removal - > 'y' for removing values flagged by GESLA
            %    cflag_removal - > remove values by entering numbers that correspond to flags by the contributor (e.g., [2,4,5])
            %                      0 - no quality control
            %                      1 - correct value 
            %                      2 - interpolated value
            %                      3 - doubtful value
            %                      4 - isolated spike or wrong value
            %                      5 - missing value
            %
            % OUTPUT, struct 'data' containing for each site:
            %    ts -> time in datetime 
            %    sl -> tide gauge sea level measurements (with or w/o flag corrections)
            %    cont_fl -> flag - contributor flags
            %    gesla_fl -> flag - gesla checks, 0 = flagged value, 1 = correct value
            %    lat -> latitude
            %    lon -> longitude
            %    datum -> datum information
            %    gauge -> gauge type and information (e.g., 'bubbler - coastal')
            %    cont_fl_info -> flag information from the contributor to be used with cont_fl
            % 
            % Removes wrong values as defined in metadata
            % Removes NULL values as defined in metadata
            %... Luke Jenkins, May 2022
        
            md = readtable(metadata);

            scoords = [md.LONGITUDE md.LATITUDE];
            i = cell2mat(knnsearch(scoords,coords,'K',n,'IncludeTies',true))';

            filenames = string(md.FILENAME(i));
        
            data = gesla.load_file(filenames,path,gflag_removal,cflag_removal);
        
        end

        function data = load_country(country,path,metadata,gflag_removal,cflag_removal)
            % Function to load data in GESLA-3 files from specific country
            % INPUT: 
            %    country -> 3 letter country code used in GESLA, e.g. 'GBR' or 'JPN'
            %               takes as many country codes as you give as either string or char array
            %    path -> directory to where the GESLA data files are kept
            %    metadata -> directory and filename for the metadata
            %    gflag_removal - > 'y' for removing values flagged by GESLA
            %    cflag_removal - > remove values by entering numbers that correspond to flags by the contributor (e.g., [2,4,5])
            %                      0 - no quality control
            %                      1 - correct value 
            %                      2 - interpolated value
            %                      3 - doubtful value
            %                      4 - isolated spike or wrong value
            %                      5 - missing value
            %
            % OUTPUT, struct 'data' containing for each site:
            %    ts -> time in datetime 
            %    sl -> tide gauge sea level measurements (with or w/o flag corrections)
            %    cont_fl -> flag - contributor flags
            %    gesla_fl -> flag - gesla checks, 0 = flagged value, 1 = correct value
            %    lat -> latitude
            %    lon -> longitude
            %    datum -> datum information
            %    gauge -> gauge type and information (e.g., 'bubbler - coastal')
            %    cont_fl_info -> flag information from the contributor to be used with cont_fl
            % 
            % Removes wrong values as defined in metadata
            % Removes NULL values as defined in metadata
            %... Luke Jenkins, May 2022
        
            md = readtable(metadata);

            filenames = string(md.FILENAME(contains(md.COUNTRY,string(country))));
        
            data = gesla.load_file(filenames,path,gflag_removal,cflag_removal);
        
        end

        function data = change_field_names(data,metadata)
            % Function change the field names in an output data struct to different GESLA format
            % INPUT: 
            %    data -> 3 data struct output from one of above functions
            %    metadata -> directory and filename for the metadata
            %    Pop up options:
            %                 'site' for GESLA site names
            %                 'country' for country (MUST BE USED IN CONJUCTION WITH SITE AND/OR CODE e.g., 'site country')
            %                 'cont' for abbreviated contributor (MUST BE USED IN CONJUCTION WITH SITE AND/OR CODE e.g., 'site code country cont')
            %                 'code' for GESLA site codes - some codes start with numbers so therefore have to be used in conjuction and at end
            %
            % OUTPUT, struct 'data' with new field names
            %... Luke Jenkins, May 2022

            md = readtable(metadata);

            dfields = string(strrep(fieldnames(data),'_',''));
            files = string(replace(md.FILENAME,{'_','-'},{''}));

            options = {string(md.SITENAME(contains(files, dfields)));...
                string(md.COUNTRY(contains(files, dfields)));...
                string(md.CONTRIBUTOR_ABBREVIATED_(contains(files, dfields)));...
                string(md.SITECODE(contains(files, dfields)))};

            prompt = {"site name","coutry","contributor (abbreviated)","site code"};
            dlgtitle = "Select new field names (Place '1' in dialogue box)";
            answer = inputdlg(prompt,dlgtitle,[1 length(char(dlgtitle))+35]);

            options = options(~cellfun(@isempty, answer));
            new_names = strings();

            for i = 1:length(options)
                switch i
                    case 1
                        new_names = append(new_names,string(options{i}));
                    otherwise
                        new_names = append(new_names,"_",string(options{i}));
                end
            end
            
            data = cell2struct(struct2cell(data), new_names);
            
        end
    
    end

end
