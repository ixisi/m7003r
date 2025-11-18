--[[
    M0073R - ver.1.0.0
    A Lua script that mute/unmute audio source based on a scene change.
]]

function setup(settings)
    obs.utils.settings= settings
    obs.register.event(function(event_id)
        if event_id == obslua.OBS_FRONTEND_EVENT_SCENE_CHANGED then
            InitAction()
        end
    end)
end
function get_scene_cz(scene_name)
    local surs= obs.utils.settings.obj("m0073r_" .. scene_name .. "_scene_t")
    if not surs or surs.data == nil then
        return nil
    end
    local alist= surs.get_arr("m0073r_clz_obs_arr_t")
    if not alist or alist.data == nil then
        surs.free()
        return nil
    end
    surs.free()
    return alist
end
function script_properties()
    local p= obs.script.create()
    obs.script.label(p, nil, "<table><tr><td width='100%' style='border-bottom: 1px solid #ccc'><b>M0073R - ver.1.0.0</b></td><td></td><td align='right'><i style='color:gray;'>by iixisii</i></td></tr></table>")
    local audible_list_count=0
    local audible_list;local add_options_error;
    local add_options;
    local add;add=obs.script.button(p, "add_new", "+", function()
        if audible_list_count <= 0 then

            return
        end
        add.hide()
        add_options_error.hide()
        add_options.show()
        return true 
    end)
    add_options= obs.script.form(p, "Adding new audible")
    add_options.hide()
    add_options_error= add_options.add.label("add_options_error","").hide()
    add_options.onconfirm:idle()
    add_options.cancel:click(function()
        add_options.hide()
        obs.utils.settings.str("audible_source", "<def-m0073r>"
        ).str("scene_name", "<def-m0073r>")
        add.show()
        return true
    end)
    add_options.confirm:click(function()
        local audible_value= obs.utils.settings.get_str("audible_source")
        if audible_value == nil or audible_value == "<def-m0073r>" then
            add_options_error.show()
            add_options_error.error("Please select a valid audible source!")
            return true
        end
        local scene_value= obs.utils.settings.get_str("scene_name")
        if scene_value == nil or scene_value == "def" then
            add_options_error.show()
            add_options_error.error("Please select a valid scene!")
            return true
        end
        -- m0073r_clz_obs_arr_t
        local surs= obs.utils.settings.obj("m0073r_" .. scene_value .. "_scene_t")

        if not surs or surs.data == nil then
            surs= obs.PairStack()
        end
        local alist= surs.get_arr("m0073r_clz_obs_arr_t")
        if not alist or alist.data == nil then
            alist= obs.ArrayStack()
            surs.arr("m0073r_clz_obs_arr_t", alist.data)
        end
        local audible= obs.PairStack()
        audible.str("source", audible_value).str(
            "scene", scene_value
        ).int("muted", 2).str("unique_id", obs.utils.get_unique_id(10))
        
        alist.insert(audible.data)
        
        obs.utils.settings.obj("m0073r_" .. scene_value .. "_scene_t", surs.data)
        audible.free()
        alist.free()
        surs.free()
        add_options.hide()
        obs.utils.settings.str("audible_source", "<def-m0073r>"
        ).str("scene_name", "<def-m0073r>")
        add.show()
        return true
    end)

    audible_list = add_options.add.options("audible_source","Audible")
    audible_list.add.str("-- Click to view options --", "<def-m0073r>")
    for _, source_name in ipairs(obs.front.source_names()) do
        local source= obs.front.source(source_name)
        local source_output_flags= obslua.obs_source_get_output_flags(source.data)
        local is_audible_source= bit.band(source_output_flags, obslua.OBS_SOURCE_AUDIO) ~= 0
        if is_audible_source then
            audible_list_count= audible_list_count + 1
            audible_list.add.str(source_name, source_name)
        end
        source.free()
    end
    if audible_list_count <= 0 then
        audible_list.add.str("No Audible Sources Found", "none").cursor().disable()
    end
    local scene_list= add_options.add.options("scene_name","Scene")
    scene_list.add.str("-- Click to view scenes --", "<def-m0073r>")

    -- [[ Populate scene list and show all the audibles ]]
        for _, scene_name in ipairs(obs.scene:names()) do
            obs.script.label(p, "label_" .. tostring(scene_name), "<b style='color:darkgray'><i>-" .. tostring(scene_name).."</i></b>")
            scene_list.add.str(scene_name, scene_name)
            local surs= obs.utils.settings.obj("m0073r_" .. scene_name .. "_scene_t")
            if surs and surs.data ~= nil then
                local alist= surs.get_arr("m0073r_clz_obs_arr_t")
                if alist and alist.data ~= nil then
                    for itm in alist.next() do
                        local audible_source= itm.get_str("source")
                        local muted_state= itm.get_int("muted")
                        local scene_value= itm.get_str("scene")
                        local unique_id= itm.get_str("unique_id")
                        local mute_action = obs.script.bool(p, audible_source .. "_" .. scene_value, audible_source)
                        if muted_state >= 2 then
                            mute_action.title(audible_source .. " ( undefined state )")
                        elseif muted_state == 1 then
                            mute_action.title(audible_source .. " ( muted )")
                        else
                            mute_action.title(audible_source .. " ( unmuted )")
                        end
                        local delete_tick=os.clock()
                        mute_action.onchange(function(value, property)
                            local delete_tick_value=os.clock() - delete_tick
                            if delete_tick_value >= 0.15 and delete_tick_value <= 0.35 then
                                -- delete the item from list
                                local alist= get_scene_cz(scene_name)
                                if not alist then
                                    return false
                                end
                                local iter, index= alist.find("unique_id", unique_id)
                                if iter then
                                    iter.free()
                                    alist.rm(index)
                                end
                                alist.free()
                                property.remove()
                                return true
                            end
                            if delete_tick_value <= 0.015 then
                                return false
                            end
                            
                            delete_tick=os.clock()
                            local alist= get_scene_cz(scene_name)
                            local iter= alist.find("source", audible_source)
                            if not iter then
                                alist.free()
                                return false
                            else
                                iter.int("muted", value and 1 or 0)
                                iter.free()
                            end
                            if value then
                                mute_action.title(audible_source .. " ( muted )")
                                
                            else
                                mute_action.title(audible_source .. " ( unmuted )")
                            end
                            InitAction()
                            return true
                        end)
                        itm.free()
                    end
                    alist.free()
                end
                surs.free()
            end
        end
    
    return p
end
function InitAction()
    local scene_name= obs.scene:name()
    local alist= get_scene_cz(scene_name)
    if not alist then
        return
    end
    for itm in alist.next() do
        local audible_source_name= itm.get_str("source")
        local muted_state= itm.get_int("muted")
        local source= obs.front.source(audible_source_name)
        if source and source.data ~= nil then
            if muted_state == 1 then
                obslua.obs_source_set_muted(source.data, true)
            else
                obslua.obs_source_set_muted(source.data, false)
            end
        end
        source.free()
        itm.free()
    end
    alist.free()
end





--[[
    Author: iixisii
    contact: @iixisii
]]


-- [[ OBS CUSTOM API BEGIN ]]
    -- [[ OBS CUSTOM CALLBACKS ]]
        function script_load(settings)
            obs.script_shutdown=false
            settings= obs.PairStack(settings)
            obs.utils.settings= settings
            if setup and type(setup) == "function" then
                setup(settings)
            end

            for _, filter in pairs(obs.utils.filters) do
                obslua.obs_register_source(filter)
            end
        end
        function script_save(settings)
            -- [[ OBS REGISTER HOTKEY SAVE DATA]]
                for name, iter in pairs(obs.register.hotkey_id_list) do
                    local new_data= obslua.obs_hotkey_save(iter.id)
                    if new_data then
                        obs.utils.settings.arr(name, new_data)
                        obslua.obs_data_array_release(new_data)
                    end
                end
            -- [[ OBS REGISTER HOTKEY SAVE DATA END]]
        end
        function script_unload()
            obs.utils.script_shutdown=true
        end
    -- [[ OBS CUSTOM CALLBACKS END ]]









	obs={utils={script_shutdown=false,
	OBS_SCENEITEM_TYPE = 1;OBS_SRC_TYPE = 2;OBS_OBJ_TYPE = 3;
	OBS_ARR_TYPE = 4;OBS_SCENE_TYPE = 5;OBS_SCENEITEM_LIST_TYPE = 6;
	OBS_SRC_LIST_TYPE = 7;OBS_UN_IN_TYPE = -1;table={};
	expect_wrapper={},
	properties={
		list={};options={};
	};filters={}};scene={};client={};mem={};script={},enum={
		path={
			read=obslua.OBS_PATH_FILE;write=obslua.OBS_PATH_FILE_SAVE;folder=obslua.OBS_PATH_DIRECTORY
		};
		button={
			default=obslua.OBS_BUTTON_DEFAULT;url=obslua.OBS_BUTTON_URL;
		};list={
			string=obslua.OBS_EDITABLE_LIST_TYPE_STRINGS;
			url=obslua.OBS_EDITABLE_LIST_TYPE_FILES_AND_URLS;
			file=obslua.OBS_EDITABLE_LIST_TYPE_FILES
		};
		text={
			error=obslua.OBS_TEXT_INFO_ERROR;
			default=obslua.OBS_TEXT_INFO;
			warn=obslua.OBS_TEXT_INFO_WARNING;
			input=obslua.OBS_TEXT_DEFAULT;password=obslua.OBS_TEXT_PASSWORD;
			textarea=obslua.OBS_TEXT_MULTILINE;
		};group={
			normal= obslua.OBS_GROUP_NORMAL;checked= obslua.OBS_GROUP_CHECKABLE;
		};options={
			string=obslua.OBS_COMBO_FORMAT_STRING; int=obslua.OBS_COMBO_FORMAT_INT;
			float=obslua.OBS_COMBO_FORMAT_FLOAT;bool=obslua.OBS_COMBO_FORMAT_BOOL;
			edit=obslua.OBS_COMBO_TYPE_EDITABLE;default=obslua.OBS_COMBO_TYPE_LIST;
			radio=obslua.OBS_COMBO_TYPE_RADIO;
		};number={
			int=obslua.OBS_COMBO_FORMAT_INT;float=obslua.OBS_COMBO_FORMAT_FLOAT;
			slider=1000;input=2000
		}
	},register={
        hotkey_id_list={},event_id_list={}
    };front={}};
	bit= require('bit')
	-- dkjson= require('dkjson')
	math.randomseed(os.time())
	-- schedule an event
	scheduled_events = {}

    -- [[  MEMORY MANAGE API ]]
        function obs.utils.scheduler(timeout)
            -- if type(timeout) ~= "number" or timeout < 0 then
            --     return obs.script_log(obslua.LOG_ERROR, "[Scheduler] invalid timeout value")
            -- end
            local scheduler_callback = nil
            local function interval()
                obslua.timer_remove(interval)
                if type(scheduler_callback) ~= "function" then
                    return
                end
                return scheduler_callback(scheduler_callback)
            end
            
            local self = nil; self = {
                after = function(callback)
                    if type(callback) == "function" or type(timeout) ~= "number" or timeout < 0 then
                        scheduler_callback = callback
                    else
                        obslua.script_log(obslua.LOG_ERROR, "[Scheduler] invalid callback/timeout " .. type(callback))
                        return false
                    end
                    obslua.timer_add(interval, timeout)
                end;push = function(callback)
                    if callback == nil or type(callback) ~= "function" then
                        obslua.script_log(obslua.LOG_WARNING, "[Scheduler] invalid callback at {push} " .. type(callback))
                        return false
                    end
                    obslua.timer_add(callback, timeout)
                    table.insert(scheduled_events, callback)
                    return {
                        clear = function()
                            if callback == nil or type(callback) ~= "function" then
                                return nil
                            end
                            return obslua.timer_remove(callback)
                        end;
                    }
                end; clear = function()
                    if scheduler_callback ~= nil then
                        obslua.timer_remove(scheduler_callback)
                    end
                    for _, clb in pairs(scheduled_events) do
                        obslua.timer_remove(clb)
                    end
                    scheduled_events = {}; scheduler_callback = nil
                end;update=function(timeout_t)
                    if type(timeout_t) ~= "number" or timeout_t < 0 then
                        obslua.script_log(obslua.LOG_ERROR, "[Scheduler] invalid timeout value")
                        return false
                    end
                    timeout= timeout_t
                    return self
                end
            }
            return self
        end

        function obs.wrap(object, object_type)
            local self = nil
            self = {
                type = object_type, data = object;item=object;
                get_source=function()
                    if self.type == obs.utils.OBS_SRC_TYPE then
                        return self.data
                    elseif self.type == obs.utils.OBS_SCENEITEM_TYPE then
                        return obslua.obs_sceneitem_get_source(self.data)
                    else
                        return self.data
                    end
                end;released=false;
                free = function()
                    if self.data == nil or self.released then
                        return
                    end
                    if self.type == obs.utils.OBS_SCENE_TYPE then
                        obslua.obs_scene_release(self.data)
                        self.data = nil;self.item=nil;self.released=true
                    elseif self.type == obs.utils.OBS_SRC_TYPE then
                        obslua.obs_source_release(self.data)
                        self.data = nil;self.item=nil;self.released=true
                    elseif self.type == obs.utils.OBS_ARR_TYPE then
                        obslua.obs_data_array_release(self.data)
                        self.data = nil;self.item=nil;self.released=true
                    elseif self.type == obs.utils.OBS_OBJ_TYPE then
                        obslua.obs_data_release(self.data)
                        self.data = nil;self.item=nil;self.released=true
                    elseif self.type == obs.utils.OBS_SCENEITEM_TYPE then
                        obslua.obs_sceneitem_release(self.data)
                        self.data = nil;self.item=nil;self.released=true
                    elseif self.type == obs.utils.OBS_SCENEITEM_LIST_TYPE then
                        obslua.sceneitem_list_release(self.data)
                        self.data = nil;self.item=nil;self.released=true
                    elseif self.type == obs.utils.OBS_SRC_LIST_TYPE then
                        obslua.source_list_release(self.data)
                        self.data = nil;self.item=nil;self.released=true
                    elseif self.type == obs.utils.OBS_UN_IN_TYPE then
                        self.data = nil;self.item=nil;self.released=true
                        return
                    else
                        self.data = nil
                    end
                end
            }
            table.insert(obs.utils.expect_wrapper, self)
            return self
        end

        function obs.expect(callback)
            return function(...)
                local args = {...}
                local data = nil
                local caller = ""
                for i, v in ipairs(args) do
                    if caller ~= "" then
                        caller = caller .. ","
                    end
                    caller = caller .. "args[" .. tostring(i) .. "]"
                end
                caller = "return function(callback,args) return callback(" .. caller .. ") end";
                local run = loadstring(caller)
                local success, result = pcall(function()
                    data = run()(callback, args)
                end)
                local free_count=0
                if not success then
                    for _, iter in pairs(obs.utils.expect_wrapper) do
                        if iter and type(iter.free) == "function" then
                            local s, r = pcall(function()
                                iter.free()
                            end)
                            if s then
                                free_count = free_count + 1
                            end
                        end
                    end
                    obslua.script_log(obslua.LOG_ERROR, "[ErrorWrapper ERROR] => " .. tostring(result))
                end
                return data
            end
        end
        -- array handle
        function obs.ArrayStack(stack, name, fallback)
            if fallback == nil then
                fallback=true
            end
            local self = nil
            self = {
                index = 0;get = function(index)
                    if type(index) ~= "number" or index < 0 or index > self.size() then
                        return nil
                    end
                    return obs.PairStack(obslua.obs_data_array_item(self.data, index), nil, true)
                end;next = obs.expect(function(__index)
                    if type(self.index) ~= "number" or self.index < 0 or self.index > self.size() then
                        return assert(false,"[ArrayStack] Invalid data provided or corrupted data for (" .. tostring(name)..")")
                    end
                    return coroutine.wrap(function()
                        if self.size() <= 0 then
                            return nil
                        end
                        local i =0
                        if __index == nil or type(__index) ~= "number" or __index < 0 or __index > self.size() then
                            __index=0
                        end
                        for i=__index, self.size()-1 do
                            coroutine.yield(obs.PairStack(
                                obslua.obs_data_array_item(self.data, i), nil, false
                            ))
                        end
                    end)
                    -- local temp = self.index;self.index = self.index + 1
                    -- return obs.PairStack(obslua.obs_data_array_item(self.data, temp), nil, true)
                end);find= function(key, value)
                    local index=0
                    for itm in self.next() do
                        if itm.get_str(key) == value or itm.get_int(key) == value 
                        or itm.get_bul(key) == value or itm.get_dbl(key) == value then
                            return itm, index
                        end
                        index = index + 1
                        itm.free()
                    end
                    return nil, nil
                end;
                
                free = function()
                    if self.data == nil then
                        return false
                    end
                    obslua.obs_data_array_release(self.data)
                    self.data = nil
                    return true
                end;insert = obs.expect(function(value)
                    if value == nil or type(value) ~= "userdata" then
                        obslua.script_log("FAILED TO INSERT OBJECT INTO [ArrayStack]")
                        return false
                    end
                    obslua.obs_data_array_push_back(self.data, value)
                    return self
                end); size = obs.expect(function()

                    if self.data == nil then
                        return 0
                    end
                    return obslua.obs_data_array_count(self.data);
                end); rm= obs.expect(function(idx)
                    if idx < 0 or self.size() <=0 or idx > self.size() then
                        obslua.script_log("FAILED TO RM DATA FROM [ArrayStack] (INVALID INDEX)")
                        return false
                    end
                    obslua.obs_data_array_erase(self.data, idx)
                    return self
                end)
            }
            if stack and name  then
                self.data = obslua.obs_data_get_array(stack, name)
            elseif not stack and fallback then
                self.data = obslua.obs_data_array_create()
            else
                self.data = stack
            end
            table.insert(obs.utils.expect_wrapper, self)
            return self
        end
        -- pair stack used to manage memory stuff :)
        function obs.PairStack(stack, name, fallback)
            if fallback == nil then
                fallback=true
            end
            local self = nil; self = {
                free = function()
                    if self.data == nil then
                        return false
                    end
                    obslua.obs_data_release(self.data)
                    self.data = nil
                    return true
                end; str = obs.expect(function(name, value, def)
                    if name and value == nil then
                        return self.get_str(name)
                    end
                    if (name == nil or type(name) ~= "string" or name == "") or (self.data == nil or type(self.data) ~= "userdata") or (value == nil or type(value) ~="string") then
                        obslua.script_log(obslua.LOG_ERROR,"FAILED TO INSERT STR INTO [PairStack] " .. "FOR [" .. tostring(name) .. "] " .. " OF VALUE [" .. tostring(value) .. "] TYPE: " .. tostring(type(value)))
                        return false
                    end
                    if def then
                        obslua.obs_data_set_default_string(self.data, name, value)
                    else
                        obslua.obs_data_set_string(self.data, name, value)
                    end
                    return self
                end);int = obs.expect(function(name, value, def)
                    if name and value == nil then
                        return self.get_int(name)
                    end
                    if (name == nil or type(name) ~= "string" or name == "") or (self.data == nil or type(self.data) ~= "userdata") or (value == nil or type(value) ~="number") then
                        obslua.script_log(obslua.LOG_ERROR,"FAILED TO INSERT INT INTO [PairStack] " .. "FOR [" .. tostring(name) .. "] " .. " OF VALUE [" .. tostring(value) .. "] TYPE: " .. tostring(type(value)))
                        return false
                    end
                    if def then
                        obslua.obs_data_set_default_int(self.data, name, value)
                    else
                        obslua.obs_data_set_int(self.data, name, value)
                    end
                    return self
                end);dbl=obs.expect(function(name, value, def)
                    if name and value == nil then
                        return self.get_dbl(name)
                    end
                    if (name == nil or type(name) ~= "string" or name == "") or (self.data == nil or type(self.data) ~= "userdata") or (value == nil or type(value) ~="number") then
                        obslua.script_log(obslua.LOG_ERROR,"FAILED TO INSERT INT INTO [PairStack] " .. "FOR [" .. tostring(name) .. "] " .. " OF VALUE [" .. tostring(value) .. "] TYPE: " .. tostring(type(value)))
                        return nil
                    end
                    if def then
                        obslua.obs_data_set_default_double(self.data, name, value)
                    else
                        obslua.obs_data_set_double(self.data, name, value)
                    end
                    return self
                end);bul = obs.expect(function(name, value, def)
                    if name and value == nil then
                        return self.get_bul(name)
                    end
                    if (name == nil or type(name) ~= "string" or name == "") or (self.data == nil or type(self.data) ~= "userdata") or (type(value) == "nil" or type(value) ~="boolean") then
                        obslua.script_log(obslua.LOG_ERROR,"FAILED TO INSERT BUL [PairStack] " .. "FOR [" .. tostring(name) .. "] " .. " OF VALUE [" .. tostring(value) .. "] TYPE: " .. tostring(type(value)))
                        return nil
                    end
                    if def then
                        obslua.obs_data_set_default_bool(self.data, name, value)
                    else
                        obslua.obs_data_set_bool(self.data, name, value)
                    end
                    return self
                end); arr = obs.expect(function(name, value, def)
                    if name and value == nil then
                        return self.get_arr(name)
                    end
                    if (name == nil or type(name) ~= "string" or name == "") or (self.data == nil or type(self.data) ~= "userdata") or (type(value) ~="userdata") then
                        
                        obslua.script_log(obslua.LOG_ERROR,"FAILED TO INSERT ARR INTO [PairStack] " .. "FOR [" .. tostring(name) .. "] " .. " OF VALUE [" .. tostring(value) .. "] TYPE: " .. tostring(type(value)))
                        return nil
                    end
                    if def then
                        obslua.obs_data_set_default_array(self.data, name, value)
                    else
                        obslua.obs_data_set_array(self.data, name, value)
                    end
                    return self
                end); obj = obs.expect(function(name, value, def)
                    if name and value == nil then
                        return self.get_obj(name)
                    end
                    if (name == nil or type(name) ~= "string" or name == "") or (type(self.data) ~= "userdata") or (type(value) ~="userdata") then
                        obslua.script_log(obslua.LOG_ERROR,"FAILED TO INSERT OBJ INTO [PairStack] " .. "FOR [" .. tostring(name) .. "] " .. " OF VALUE [" .. tostring(value) .. "] TYPE: " .. tostring(type(value)))
                        return nil
                    end
                    if def then
                        obslua.obs_data_set_default_obj(self.data, name, value)
                    else
                        obslua.obs_data_set_obj(self.data, name, value)
                    end
                    return self
                end);
                -- getter
                get_str = obs.expect(function(name, def)
                    if (name == nil or type(name) ~= "string" or name == "") or (type(self.data) ~= "userdata")then
                        obslua.script_log(obslua.LOG_ERROR,"FAILED TO GET STR FROM [PairStack] " .. "FOR [" .. tostring(name) .. "] " .. " OF VALUE [" .. tostring(value) .. "] TYPE: " .. tostring(type(value)))
                        return nil
                    end
                    if not def then
                        return obslua.obs_data_get_string(self.data, name)
                    else
                        return obslua.obs_data_get_default_string(self.data, name)
                    end
                end);get_int = obs.expect(function(name, def)
                    if (name == nil or type(name) ~= "string" or name == "") or (type(self.data) ~= "userdata")then
                        obslua.script_log(obslua.LOG_ERROR,"FAILED TO GET INT FROM [PairStack] " .. "FOR [" .. tostring(name) .. "] " .. " OF VALUE [" .. tostring(value) .. "] TYPE: " .. tostring(type(value)))
                        return nil
                    end
                    if not def then
                        return obslua.obs_data_get_int(self.data, name)
                    else
                        return obslua.obs_data_get_default_int(self.data, name)
                    end
                end);get_dbl = obs.expect(function(name, def)
                    if (name == nil or type(name) ~= "string" or name == "") or (type(self.data) ~= "userdata")then
                        obslua.script_log(obslua.LOG_ERROR,"FAILED TO GET DBL FROM [PairStack] " .. "FOR [" .. tostring(name) .. "] " .. " OF VALUE [" .. tostring(value) .. "] TYPE: " .. tostring(type(value)))
                        return nil
                    end
                    if not def then
                        return obslua.obs_data_get_double(self.data, name)
                    else
                        return obslua.obs_data_get_default_double(self.data, name)
                    end
                end);get_obj = obs.expect(function(name, def)
                    if (name == nil or type(name) ~= "string" or name == "") or (type(self.data) ~= "userdata")then
                        obslua.script_log(obslua.LOG_ERROR,"FAILED TO GET OBJ FROM [PairStack] " .. "FOR [" .. tostring(name) .. "] " .. " OF VALUE [" .. tostring(value) .. "] TYPE: " .. tostring(type(value)))
                        return nil
                    end
                    if not def then
                        return obs.PairStack(
                            obslua.obs_data_get_obj(self.data, name),nil, false
                        )
                    else
                        return obs.PairStack(
                            obslua.obs_data_get_default_obj(self.data, name),nil, false
                        )
                    end
                end);get_arr = obs.expect(function(name, def)
                    if (name == nil or type(name) ~= "string" or name == "") or (type(self.data) ~= "userdata")then
                        obslua.script_log(obslua.LOG_ERROR,"FAILED TO GET ARR FROM [PairStack] " .. "FOR [" .. tostring(name) .. "] " .. " OF VALUE [" .. tostring(value) .. "] TYPE: " .. tostring(type(value)))
                        return nil
                    end
                    if not def then
                        return obs.ArrayStack(
                            obslua.obs_data_get_array(self.data, name),nil, false
                        )
                    else
                        return obs.ArrayStack(obslua.obs_data_get_default_array(self.data, name),nil, false)
                    end
                end);get_bul = obs.expect(function(name, def)
                    if (name == nil or type(name) ~= "string" or name == "") or (type(self.data) ~= "userdata") then
                        obslua.script_log(obslua.LOG_ERROR,"FAILED TO GET BUL FROM [PairStack] " .. "FOR [" .. tostring(name) .. "] " .. " OF VALUE [" .. tostring(value) .. "] TYPE: " .. tostring(type(value)))
                        return nil
                    end
                    if not def then
                        return obslua.obs_data_get_bool(self.data, name)
                    else
                        return obslua.obs_data_get_default_bool(self.data, name)
                    end
                end); del= obs.expect(function(name)
                    obslua.obs_data_erase(self.data, name)
                    return true
                end);
            }
            if stack and name then
                self.data = obslua.obs_data_get_obj(stack, name)
            elseif not stack and fallback then
                self.data = obslua.obs_data_create()
            else
                self.data = stack
            end
            table.insert(obs.utils.expect_wrapper, self)
            return self
        end
    -- [[ MEMORY MANAGE API END ]]

	-- [[ OBS REGISTER CUSTOM API]]
        function obs.register.hotkey(unique_id, title, callback)
            local script_path_value= script_path()
            unique_id= tostring(script_path_value) .. "_" .. tostring(unique_id)
            local hotkey_id= obslua.obs_hotkey_register_frontend(
                unique_id, title, callback
            )
            -- load from data
            local hotkey_load_data= obs.utils.settings.get_arr(unique_id);
            if hotkey_load_data and hotkey_load_data.data ~= nil then
                obslua.obs_hotkey_load(hotkey_id, hotkey_load_data.data)
                hotkey_load_data.free()
            end
            obs.register.hotkey_id_list[unique_id]= {
                id= hotkey_id, title= title, callback= callback,
                remove=function(rss)
                    if rss == nil then
                        rss= false
                    end
                    -- obs.utils.settings.del(unique_id)
                    if rss then
                        if obs.register.hotkey_id_list[unique_id] and type(obs.register.hotkey_id_list[unique_id].callback) == "function" then
                            obslua.obs_hotkey_unregister(
                                obs.register.hotkey_id_list[unique_id].callback
                            )
                        end
                    end
                    obs.register.hotkey_id_list[unique_id]= nil
                end
            }
            return obs.register.hotkey_id_list[unique_id]
        end
        function obs.register.get_hotkey(unique_id)
            unique_id= tostring(script_path()) .. "_" .. tostring(unique_id)
            if obs.register.hotkey_id_list[unique_id] then
                return obs.register.hotkey_id_list[unique_id]
            end
            return nil
        end
        function obs.register.event(unique_id, callback)
            if not callback and unique_id and type(unique_id) == "function" then
                callback= unique_id
                unique_id= tostring(script_path()) .. "_" .. obs.utils.get_unique_id(3) .. "_event"
            else
                unique_id= tostring(script_path()) .. "_" .. tostring(unique_id) .. "_event"
            end
            if type(callback) ~= "function" then
                obslua.script_log(obslua.LOG_ERROR, "[OBS REGISTER EVENT] Invalid callback provided")
                return nil
            end
            local event_id= obslua.obs_frontend_add_event_callback(callback)
            obs.register.event_id_list[unique_id]= {
                id= event_id,callback= callback,
                unique_id= unique_id,
                remove= function(rss)
                    if rss == nil then
                        rss= false
                    end
                    if rss then obslua.obs_frontend_remove_event_callback(callback) end
                    obs.register.event_id_list[unique_id]= nil
                end
            };
            
        end
        function obs.register.get_event(unique_id)
            unique_id= tostring(script_path()) .. "_" .. tostring(unique_id) .. "_event"
            if obs.register.event_id_list[unique_id] then
                return obs.register.event_id_list[unique_id]
            end
            return nil
        end
    -- [[ OBS REGISTER CUSTOM API END]]


	-- [[ OBS FILTER CUSTOM API]]
		function obs.script.filter(filter)
			local self;self={
				id= filter and filter.id or obs.utils.get_unique_id(3),
				type= filter and filter.type or obslua.OBS_SOURCE_TYPE_FILTER,
				output_flags= filter and filter.output_flags or bit.bor(
					obslua.OBS_SOURCE_VIDEO
				),
				get_height=function(src)
					return src and src.height or 0
				end, get_width= function(src)
					return src and src.width or 0
				end,update= function(_, settings)
					if filter and type(filter) == "table" and 
					filter["update"] and type(filter["update"]) == "function" then 
						return filter.update(_, obs.PairStack(settings))
					end
				end, create= function(settings, source)
                    function get_sceneitem()
                        local a_source=obslua.obs_filter_get_target(source)
                        while true do
                            local temp= obslua.obs_filter_get_target(a_source)
                            if temp == nil then break end
                            a_source= temp
                        end
                        if not a_source then return nil end
                        local source_name= obslua.obs_source_get_name(a_source)
                        local a_scene= obs.scene:get_scene()
                        if not a_scene then
                            return nil
                        end
                        local a_scene_item= a_scene.get(source_name)
                        a_scene.free()
                        return a_scene_item
                    end
					if filter and type(filter) == "table" and filter["create"]
					and type(filter["create"]) == "function" then
                        local __a_sceneitem=get_sceneitem()
						local src=filter.create(
							obs.PairStack(settings),
							__a_sceneitem
						)
                        if __a_sceneitem and __a_sceneitem.data then __a_sceneitem.free() end
                        if src ~= nil and type(src) == "table" then
                            src.sceneitem=get_sceneitem
                            self.src=src;src.filter=source
                            src.is_custom=true
                            if filter and filter["setup"] and type(filter["setup"]) == "function" then
                                filter.setup(src)
                            end
                            return src
                        end
					end

					-- default creation
					local src= {
						source= source,filter=source,
						params=nil,height=nil,isAlive=true,
                        width=nil,settings=obs.PairStack(settings),
                        sceneitem= get_sceneitem, item=get_sceneitem()
					}
					-- get width and height of source
					if source ~= nil then
						local target= obslua.obs_filter_get_target(source)
						if target ~= nil then
							src.width= obslua.obs_source_get_base_width(target)
							src.height= obslua.obs_source_get_base_height(target)
						end
					else
						src.width= 0;src.height= 0
					end
					shader = [[
						uniform float4x4 ViewProj;
						uniform texture2d image;
						uniform int width;
						uniform int height;

						sampler_state textureSampler {
							Filter    = Linear;
							AddressU  = Border;
							AddressV  = Border;
							BorderColor = 00000000;
						};
						struct VertData 
						{
							float4 pos : POSITION;
							float2 uv  : TEXCOORD0;
						};
						float4 ps_get(VertData v_in) : TARGET 
						{
							return image.Sample(textureSampler, v_in.uv.xy);
						}
						VertData VSDefault(VertData v_in)
						{
							VertData vert_out;
							vert_out.pos = mul(float4(v_in.pos.xyz, 1.0), ViewProj);
							vert_out.uv  = v_in.uv;
							return vert_out;
						}
						technique Draw
						{
							pass
							{
								vertex_shader = VSDefault(v_in);
								pixel_shader  = ps_get(v_in);
							}
						}
					]]
                    obslua.obs_enter_graphics()
                    src.shader= obslua.gs_effect_create(shader, nil, nil)
                    obslua.obs_leave_graphics()
					if src.shader ~= nil then
						src.params= {
							width= obslua.gs_effect_get_param_by_name(src.shader, "width"),
							height= obslua.gs_effect_get_param_by_name(src.shader, "height"),
							image= obslua.gs_effect_get_param_by_name(src.shader, "image"),
						}
					else
						return self.destroy()
					end
					if filter and filter["setup"] and type(filter["setup"]) == "function" then
						filter.setup(src)
					end
					self.src=src
					return src
				end, destroy= function(src)
                    src.isAlive= false
					if filter and type(filter) == "table" and filter["destroy"]
					and type(filter["destroy"]) == "function" then
						for i, v in pairs(obs.utils.filters) do
							if v == self then
								table.remove(obs.utils.filters, i)
								break
							end
						end
						local result= filter.destroy(src)
						if src and src.item and src.item.data then
							src.item.free()
						end
						if src and src.is_custom then
							return result
						end
					end

					-- default destruction
					if src and src.item and src.item.data then
						src.item.free()
					end
					if src and type(src) == "table" and src.shader then
						obslua.obs_enter_graphics()
						obslua.gs_effect_destroy(src.shader)
						obslua.obs_leave_graphics()
					end
					for i, v in pairs(obs.utils.filters) do
						if v == self then
							table.remove(obs.utils.filters, i)
							break
						end
					end
				end,video_tick=function(src, fps)
					-- get width and height of source
					if src.source ~= nil then
						local target= obslua.obs_filter_get_target(src.source)
						if target ~= nil then
							src.width= obslua.obs_source_get_base_width(target)
							src.height= obslua.obs_source_get_base_height(target)
						else
							src.width= 0;src.height= 0
						end
					else
						src.width= 0;src.height= 0
					end
					-- call user-defined video_tick function
					if filter and type(filter) == "table" and filter["video_tick"]
					and type(filter["video_tick"]) == "function" then
						filter.video_tick(src, fps)
					end
				end,
				video_render= function(src)
					if filter and type(filter) == "table" and filter["video_render"] and 
					type(filter["video_render"]) == "function" then
						local result = filter.video_render(src)
						if src.is_custom then
							return result
						end
					end
					-- default render
					if not src or not src.source or not src.shader or not src.params then
						return
					end
					if not src.item or not src.item.data then
						local target= obslua.obs_filter_get_target(src.source)
						if target ~= nil then
							src.item= src.sceneitem()
							src.width= obslua.obs_source_get_base_width(target)
							src.height= obslua.obs_source_get_base_height(target)
						end
					end
					local width= src.width;local height= src.height
					if not obslua.obs_source_process_filter_begin(
						src.source,obslua.GS_RGBA, obslua.OBS_NO_DIRECT_RENDERING
					) then
						obslua.obs_source_skip_video_filter(src.source)
						return nil
					end
					if not src.params then
						obslua.obs_source_process_filter_end(src.source, src.shader, width, height)
						return nil
					end
					if type(width) == "number" then
						obslua.gs_effect_set_int(src.params.width, width)
					end
					if type(height) == "number" then
						obslua.gs_effect_set_int(src.params.height, height)
					end
					obslua.gs_blend_state_push()
					obslua.gs_blend_function(
						obslua.GS_BLEND_ONE, obslua.GS_BLEND_INVSRCALPHA
					)
					if width and height then 
						obslua.obs_source_process_filter_end(src.source, src.shader, width, height)
					end
					obslua.gs_blend_state_pop()
					return true
				end,
				get_name=function()
					return filter and filter.name or "Custom Filter"
				end,get_defaults=function(settings)
					local defaults=nil
					if filter and type(filter) == "table" and filter["get_defaults"]
					and type(filter["get_defaults"]) == "function" then
						defaults = filter.get_defaults
					end
					if filter and type(filter) == "table" and filter["defaults"] and type(filter["defaults"]) == "function" then
						defaults = filter.defaults
					end
					if defaults and type(defaults) == "function" then
						return defaults(obs.PairStack(settings))
					end
				end,get_properties=function(src)
					local properties= nil
					if filter and type(filter) == "table" and filter["get_properties"]
					and type(filter["get_properties"]) == "function" then
						properties = filter.get_properties
					end
					if filter and type(filter) == "table" and filter["properties"] and type(filter["properties"]) == "function" then
						properties = filter.properties
					end
					if properties and type(properties) == "function" then
						return properties(src)
					end
					return nil
				end
			}
			table.insert(obs.utils.filters, self)
			if not filter or not type(filter) == "table" then
				filter={}
			end
			filter.get_name= self.get_name
			if not filter.id then
				filter.id= self.id
			end
			filter.get_width= self.get_width
			filter.get_height= self.get_height
			filter.type= self.type
			filter.output_flags= self.output_flags

			--filter.destroy= self.destroy
			return filter
		end
    -- [[ OBS FILTER CUSTOM API END]]

	--[[ OBS SCENE API CUSTOM ]]
        function obs.scene:get_source(source_name)
            if not source_name or not type(source_name) == "string" then
                return nil
            end
            local source = obslua.obs_get_source_by_name(source_name)
            if not source then
                return nil
            end
            return obs.wrap(source, obs.utils.OBS_SRC_TYPE)
        end

        function obs.scene:get_scene(scene_name)
            local scene;local source_scene;
            if not scene_name or not type(scene_name) == "string" then
                source_scene=obslua.obs_frontend_get_current_scene()
                if not source_scene then
                    return nil
                end
                scene= obslua.obs_scene_from_source(source_scene)
            else
                source_scene= obslua.obs_get_source_by_name(scene_name)
                if not source_scene then
                    return nil
                end
                scene=obslua.obs_scene_from_source(source_scene)
            end
            local obj_scene_t;obj_scene_t= {
                group_names=function()
                    local scene_items_list = obs.wrap(
                        obslua.obs_scene_enum_items(scene),
                        obs.utils.OBS_SCENEITEM_LIST_TYPE
                    )
                    if scene_items_list == nil or scene_items_list.data == nil then
                        return nil
                    end
                    local list={}
                    for _, item in ipairs(scene_items_list.data) do
                        local source = obslua.obs_sceneitem_get_source(item)
                        if source ~= nil then
                            local sourceName = obslua.obs_source_get_name(source)
                            if obslua.obs_sceneitem_is_group(item) then
                                table.insert(list, sourceName)
                            end
                        end
                    end
                    scene_items_list.free()
                    return list
                end;source_names=function(source_id_type)
                    local scene_nodes_name_list= {}
                    local scene_items_list = obs.wrap(
                        obslua.obs_scene_enum_items(scene),
                        obs.utils.OBS_SCENEITEM_LIST_TYPE
                    )
                    for _, item in ipairs(scene_items_list.data) do
                        local source = obslua.obs_sceneitem_get_source(item)
                        if source ~= nil then
                            local sourceName = obslua.obs_source_get_name(source)
                            if source_id_type == nil or type(source_id_type) ~= "string" or source_id_type == "" then
                                table.insert(scene_nodes_name_list, sourceName)
                            else
                                local sourceId = obslua.obs_source_get_id(source)
                                if sourceId == source_id_type then
                                    table.insert(scene_nodes_name_list, sourceName)
                                end
                            end
                            source= nil
                        end
                    end
                    scene_items_list.free()
                    return scene_nodes_name_list
                end;get= function(source_name)
                    if not scene  then
                        return nil
                    end
                    local c=1
                    local scene_item;local scene_items_list = obs.wrap(
                        obslua.obs_scene_enum_items(scene),
                        obs.utils.OBS_SCENEITEM_LIST_TYPE
                    )
                    if scene_items_list == nil or scene_items_list.data == nil then
                        return nil
                    end
                    for _, item in ipairs(scene_items_list.data) do
                        c = c + 1
                        local src= obslua.obs_sceneitem_get_source(item)
                        local src_name= obslua.obs_source_get_name(src)
                        if src ~= nil and src_name == source_name then
                            obslua.obs_sceneitem_addref(item)
                            scene_item= obs.wrap(item, obs.utils.OBS_SCENEITEM_TYPE)
                            break
                        end
                    end
                    scene_items_list.free()
                    if scene_item == nil or scene_item.data == nil then
                        return nil
                    end
                    local obj_source_t;
                    obj_source_t={
                        free=scene_item.free;
                        item=scene_item.data;
                        data=scene_item.data;
                        get_source=function()
                            return obslua.obs_sceneitem_get_source(scene_item.data)
                        end;get_name= function()
                            return obslua.obs_source_get_name(obj_source_t.get_source())
                        end;

                        
                    }
                    return obj_source_t
                end;add=function(source)
                    if not source then return false end
                    local sceneitem= obslua.obs_scene_add(scene, source)
                    if sceneitem == nil then return nil end
                    obslua.obs_sceneitem_addref(sceneitem)
                    return obs.wrap(sceneitem, obs.utils.OBS_SCENEITEM_TYPE)
                end;get_label=function(name, source)
                    if (source == nil or source.data == nil) and name ~= nil and type(name) == "string" and name ~= "" then
                        source= obj_scene_t.get(name)
                    end
                    if not source or not source.data then
                        return nil 
                    end
                    local obj_label_t;obj_label_t={
                        remove= function()
                            if obj_label_t.data == nil then return true end
                            obslua.obs_sceneitem_remove(obj_label_t.data)
                            source.free(); obj_label_t.data=nil;obj_label_t.item=nil
                            return true
                        end;
                        hide= function()
                            return obslua.obs_sceneitem_set_visible(obj_label_t.data, false)
                        end;show = function()
                            return obslua.obs_sceneitem_set_visible(obj_label_t.data, true)
                        end;
                        font= {
                            size= function(font_size)
                                local src= obs.PairStack(
                                    obslua.obs_source_get_settings(source.get_source()),
                                    nil,true
                                )
                                if not src or not src.data then
                                    src= obs.PairStack()
                                end
                                local font= src.get_obj("font")
                                if not font or not font.data then
                                    font= obs.PairStack()
                                    --font.str("face","Arial")
                                end
                                if font_size == nil or not type(font_size) == "number" or font_size <= 0 then
                                    font_size=font.get_int("size")
                                    font.free();src.free();
                                    return font_size
                                else
                                    font.int("size", font_size)
                                end
                                font.free();
                                obslua.obs_source_update(source.get_source(), src.data)
                                src.free()
                                return true
                            end;face= function(face_name)
                            end
                        };text=function(txt)
                            local src= obs.PairStack(
                                obslua.obs_source_get_settings(source.get_source()),
                                nil,true
                            )
                            if not src or not src.data then
                                src= obs.PairStack()
                            end
                            local res=true
                            if txt == nil or txt == "" or type(txt) ~= "string" then
                                res=src.get_str("text")
                                if not res == nil then
                                    res= ""
                                end
                            else
                                src.str("text", txt)
                            end
                            obslua.obs_source_update(source.get_source(), src.data)
                            src.free()
                            return res
                        end;free=function()
                            source.free()
                            obj_label_t=nil
                            return true
                        end;data=source.data;item=source.data;size={
                            width= function(w)

                                --local default_transform= obslua.obs_transform_info()
                                --local default_source_info=obslua.obs_source_info()
                                --obslua.obs_source_get_info(source.get_source(), default_source_info)
                                --obslua.obs_sceneitem_get_info2(source.data, default_transform)
                                local default_width= obslua.obs_source_get_width(source.get_source())
                                --local default_scale_x= default_transform.scale.x;

                                if w == nil then return default_width end
                                return w
                            end;
                            height= function(h)
                                local default_height= obslua.obs_source_get_height(source.get_source())
                                if h == nil then return default_height end
                                return h
                            end;
                        };pos = {
                            x=function(val)
                                local default_transform= obslua.obs_transform_info()
                                obslua.obs_sceneitem_get_info2(source.data, default_transform)
                                if val == nil then return default_transform.pos.x end
                                default_transform.pos.x= val
                                obslua.obs_sceneitem_set_info(source.data, default_transform)
                                return true
                            end;
                            y=function(val)
                                local default_transform= obslua.obs_transform_info()
                                obslua.obs_sceneitem_get_info2(source.data, default_transform)
                                if val == nil then return default_transform.pos.y end
                                default_transform.pos.y= val
                                obslua.obs_sceneitem_set_info(source.data, default_transform)
                                return true
                            end;
                        }
                    }
                    return obj_label_t
                end;
                add_label= function(name, text)
                    local src= obs.PairStack()
                    if not text then
                        text= "Text - Label"
                    end
                    src.str("text", text)
                    local source_label=obslua.obs_source_create("text_gdiplus", name, src.data, nil)
                    src.free()
                    local obj= obj_scene_t.get_label(
                        nil, obj_scene_t.add(source_label)
                    )
                    if not obj or not obj.data then 
                        if source_label then obslua.obs_source_release(source_label) end
                        return nil
                    end
                    -- re-write the release function
                    -- [[SEEM LIKE THIS LEADS TO CRUSHES?]]
                    local free_func= obj.free;
                    obj.free= function()
                        obslua.obs_source_release(source_label)
                        return free_func()
                    end
                    return obj
                end;add_group= function(name, refresh)
                    if refresh == nil then
                        refresh=true
                    end
                    local obj=obj_scene_t.get_group(nil, obslua.obs_scene_add_group2(scene, name, refresh))
                    if not obj or obj.data == nil then return nil end
                    -- overwrite the free function to prevent crush/bugs
                    obj.free=function() end
                    return obj
                end;get_group= function(name, gp)
                    local obj;if not gp and name ~= nil then
                        obj= obs.wrap(obslua.obs_scene_get_group(scene, name), obs.utils.OBS_SCENEITEM_TYPE)
                    elseif gp ~= nil then
                        obj= obs.wrap(gp, obs.utils.OBS_SCENEITEM_TYPE)
                    else
                        return nil
                    end
                    obj["add"]= function(sceneitem)
                        if not sceneitem then
                            return false
                        end
                        obslua.obs_sceneitem_group_add_item(obj.data, sceneitem)
                        return true
                    end
                    obj["release"]= function()
                        return obj.free()
                    end;obj["item"]= obj.data
                    return obj
                end;free= function()
                    obslua.obs_source_release(source_scene)
                    scene=nil
                end;release= function()
                    return obj_scene_t.free()
                end;get_width= function()
                    return obslua.obs_source_get_base_width(source_scene)
                end;get_height = function()
                    return obslua.obs_source_get_base_height(source_scene)
                end;data=scene;item=scene;
            };
            return obj_scene_t
        end

        function obs.scene:name()
            source_scene=obslua.obs_frontend_get_current_scene()
            if not source_scene then
                return nil
            end
            local source_name= obslua.obs_source_get_name(source_scene)
            obslua.obs_source_release(source_scene)
            return source_name
        end
        function obs.scene:add_to_scene(source)
            if not source then
                return false
            end
            local current_source_scene= obslua.obs_frontend_get_current_scene()
            if not current_source_scene then
                return false
            end
            local current_scene= obslua.obs_scene_from_source(current_source_scene)
            if not current_scene then
                obslua.obs_source_release(current_source_scene)
                return false
            end
            obslua.obs_scene_add(current_scene, source)
            obslua.obs_source_release(current_source_scene)
            return true
        end
        function obs.scene:names()
            local scenes= obs.wrap(
                obslua.obs_frontend_get_scenes(),
                obs.utils.OBS_SRC_LIST_TYPE
            );
            local obj_table_t= {}
            for _, a_scene in pairs(scenes.data) do
                if a_scene then
                    local scene_source_name= obslua.obs_source_get_name(a_scene)
                    table.insert(obj_table_t, scene_source_name)
                end
            end
            scenes.free()
            return obj_table_t
        end
    --[[ OBS SCENE API CUSTOM END ]]
    -- [[ OBS FRONT API ]]
        function obs.front.source_names()
            local list={}
            local all_sources= obs.wrap(
                obslua.obs_enum_sources(),
                obs.utils.OBS_SRC_LIST_TYPE
            );
            for _, source in pairs(all_sources.data) do
                if source then
                    local source_name= obslua.obs_source_get_name(source)
                    table.insert(list, source_name)
                end
            end
            all_sources.free()
            return list
        end
        function obs.front.source(source_name)
            if not source_name or not type(source_name) == "string" then
                return nil
            end
            local source = obslua.obs_get_source_by_name(source_name)
            if not source then
                return nil
            end
            return obs.wrap(source, obs.utils.OBS_SRC_TYPE)
        end
    -- [[ OBS FRONT API END ]]
	-- [[ OBS SCRIPT PROPERTIES CUSTOM API]]
        function obs.script.create()
            return obslua.obs_properties_create()
        end
        function obs.script.options(p, unique_id, desc, enum_type_id, enum_format_id)
            if not desc or type(desc) ~= "string" then
                desc=""
            end
            if not unique_id or type(unique_id) ~= "string" or unique_id == ""  then
                unique_id= obs.utils.get_unique_id(20)
            end
            if enum_format_id == nil then
                enum_format_id= obs.enum.options.string;
            end
            if enum_type_id == nil then
                enum_type_id= obs.enum.options.default;
            end
            local obj=obslua.obs_properties_add_list(p, unique_id, desc, enum_type_id, enum_format_id);
            if not obj then
                obslua.script_log(obslua.LOG_ERROR, "[obsapi_custom.lua] Failed to create list property: " .. tostring(unique_id) .. " description: " .. tostring(desc) .. " enum_type_id: " .. tostring(enum_type_id) .. " enum_format_id: " .. tostring(enum_format_id))
                return nil
            end
            
            obs.utils.properties.options[unique_id]= {
                enum_format_id= enum_format_id;
                enum_type_id= enum_type_id;type=enum_format_id
            }
            return obs.utils.obs_api_properties_patch(obj, p)
        end
        function obs.script.button(p, unique_id, label, callback)
            if not label or type(label) ~= "string" then
                label="button"
            end
            if not unique_id or type(unique_id) ~= "string" or unique_id == ""  then
                unique_id= obs.utils.get_unique_id(20)
            end
            if type(callback)~="function" then callback=function() end end
            obs.utils.properties[unique_id]=obs.utils.obs_api_properties_patch(
                obslua.obs_properties_add_button(p, unique_id, label, function(properties_t, property_t, obs_data_t)
                    return callback(properties_t, property_t, obs.PairStack(obs_data_t))
                end)
            ,p)
            return obs.utils.properties[unique_id]
        end
        function obs.script.label(p, unique_id, text, enum_type)
            if not text or type(text) ~= "string" then
                text=""
            end
            if not unique_id or type(unique_id) == nil or unique_id == "" or type(unique_id) ~= "string" then
                unique_id= obs.utils.get_unique_id(20)
            end
            local default_enum_type= obslua.OBS_TEXT_INFO;
            if(enum_type == nil) then
                enum_type= default_enum_type
            end
            local obj= obs.utils.obs_api_properties_patch(obslua.obs_properties_add_text(p, unique_id, text, default_enum_type), p)
            if enum_type == obs.enum.text.error then
                obj.error(text)
            elseif enum_type == obs.enum.text.warn then
                obj.warn(text)
            end
            obj.type= enum_type;
            obs.utils.properties[unique_id]= obj
            return obj;

        end 
        function obs.script.group(p, unique_id, desc, op, enum_type)
            if not desc or type(desc) ~= "string" then
                desc=""
            end
            if not unique_id or type(unique_id) ~= "string" or unique_id == ""  then
                unique_id= obs.utils.get_unique_id(20)
            end
            if enum_type == nil then
                enum_type= obs.enum.group.normal;
            end
            -- if enum_type == obs.enum.group.bool and obs.utils.settings.get_bul(unique_id) == nil then
            --     obs.utils.settings.bul(unique_id, false)
            -- end
            obs.utils.properties[unique_id]= obs.utils.obs_api_properties_patch(obslua.obs_properties_add_group(p, unique_id, desc, enum_type, op), p)
            return obs.utils.properties[unique_id]
        end
        function obs.script.bool(p, unique_id, desc)
            if not desc or type(desc) ~= "string" then
                desc=""
            end
            if not unique_id or type(unique_id) ~= "string" or unique_id == ""  then
                unique_id= obs.utils.get_unique_id(20)
            end
            -- create a default value
            -- if obs.utils.settings.get_bul(name) == nil then
            -- 	obs.utils.settings.bul(name, false)
            -- end
            obs.utils.properties[unique_id]=obs.utils.obs_api_properties_patch(obslua.obs_properties_add_bool(p, unique_id, desc), p)
            return obs.utils.properties[unique_id]
        end
        function obs.script.path(p, unique_id, desc, enum_type_id, filter_string, default_path_string)
            if not unique_id or type(unique_id) ~= "string" or unique_id == ""  then
                unique_id= obs.utils.get_unique_id(20)
            end
            if not desc or type(desc) ~= "string" then
                desc= ""
            end
            if enum_type_id == nil or type(enum_type_id) ~= "number" then
                enum_type_id= obs.enum.path.read
            end
            if filter_string == nil or type(filter_string) ~= "string" then
                filter_string=""
            end
            if default_path_string == nil or type(default_path_string) ~= "string" then
                default_path_string= ""
            end
            obs.utils.properties[unique_id]= obs.utils.obs_api_properties_patch(obslua.obs_properties_add_path(p, unique_id, desc, enum_type_id, filter_string, default_path_string), p)
            return obs.utils.properties[unique_id]
        end
        function obs.script.form(properties, title, unique_id)
            local pp= obs.script.create();local __exit_click_callback__=nil;local __onexit_type__=1;
            local __cancel_click_callback__=nil;local __oncancel_type__=1;
            if unique_id == nil then
                unique_id=obs.utils.get_unique_id(20)
            end
            local group_form= obs.script.group(properties,unique_id, "", pp, obs.enum.group.normal)
            local label= obs.script.label(pp, unique_id .. "_label", title, obslua.OBS_TEXT_INFO);
            obs.script.label(pp,"form_tt","<hr/>", obslua.OBS_TEXT_INFO);
            local ipp= obs.script.create()
            local group_inner= obs.script.group(pp, unique_id .. "_inner", "", ipp, obs.enum.group.normal)
            local exit= obs.script.button(pp, unique_id .. "_exit", "Confirm",function(pp, s, ss)
                if __exit_click_callback__ and type(__exit_click_callback__) == "function" then
                    __exit_click_callback__(pp,s, ss)
                end
                if __onexit_type__ == -1 then
                    group_form.free()
                elseif __onexit_type__ == 1 then
                    group_form.hide()
                end
                return true
            end)
            local cancel= obs.script.button(pp, unique_id .. "_cancel", "Cancel", function(pp, s, ss)
                if __cancel_click_callback__ and type(__cancel_click_callback__) == "function" then
                    __cancel_click_callback__(pp,s, ss)
                end
                if __oncancel_type__ == -1 then
                    group_form.free()
                elseif __oncancel_type__ == 1 then
                    group_form.hide()
                end
                return true
            end)
            local obj_t;obj_t={
                add={
                    button= function(...)
                        return obs.script.button(ipp, ...)
                    end;options= function(...)
                        return obs.script.options(ipp,...)
                    end;label= function(...)
                        return obs.script.label(ipp,...)
                    end;group= function(...)
                        return obs.script.group(ipp, ...)
                    end;bool= function(...)
                        return obs.script.bool(ipp, ...)
                    end;path=function(...)
                        return obs.script.path(ipp,...)
                    end;input= function(...)
                        return obs.script.input(ipp, ...)
                    end;number=function(...)
                        return obs.script.number(ipp, ...)
                    end
                };get= function(name)
                    return obs.script.get(ipp,name)
                end;free= function()
                    group_form.free();
                    obslua.obs_properties_destroy(ipp);ipp=nil
                    obslua.obs_properties_destroy(pp);pp=nil
                    return true
                end;data=ipp;item=ipp;confirm={};onconfirm={};oncancel={};cancel={}
            }
            function obj_t.confirm:click(clb)
                __exit_click_callback__=clb
                return obj_t
            end;function obj_t.confirm:text(title_value)
                if not title_value or type(title_value) ~= "string" or title_value == "" then
                    return false
                end
                exit.text(title_value)
                return true
            end
            function obj_t.onconfirm:hide()
                __onexit_type__= 1
                return obj_t
            end;function obj_t.onconfirm:remove()
                __onexit_type__=-1
                return obj_t
            end;function obj_t.onconfirm:idle()
                __onexit_type__= 0
                return obj_t
            end

            function obj_t.cancel:click(clb)
                __cancel_click_callback__=clb
                return obj_t
            end;function obj_t.cancel:text(txt)
                if not txt or type(txt) ~= "string" or txt == "" then
                    return false
                end
                cancel.text(txt)
                return true
            end
            function obj_t.oncancel:idle()
                __oncancel_type__= 0
                return obj_t
            end;function obj_t.oncancel:remove()
                __oncancel_type__= -1
                return obj_t
            end;function obj_t.oncancel:hide()
                __oncancel_type__= 1
                return obj_t
            end
            function obj_t.show()
                return group_form.show();
            end;function obj_t.hide()
                return group_form.hide();
            end;function obj_t.remove()
                return obj_t.free()
            end
            obs.utils.properties[unique_id]= obj_t
            return obj_t
        end
        function obs.script.fps(properties_t, unique_id, title)
            if not title or type(title) ~= "string" then
                title=""
            end
            if not unique_id or type(unique_id) ~= "string" or unique_id == ""  then
                unique_id= obs.utils.get_unique_id(20)
            end
            obs.utils.properties[unique_id]=obs.utils.obs_api_properties_patch(
                obslua.obs_properties_add_frame_rate(properties_t, unique_id, title),
                properties_t
            )
            return obs.utils.properties[unique_id]
        end
        function obs.script.list(properties_t, unique_id, title, enum_type_id, filter_string, default_path_string)
            if not filter_string or type(filter_string) ~= "string" then
                filter_string=""
            end
            if not default_path_string or type(default_path_string) ~= "string" then
                default_path_string= ""
            end
            if not enum_type_id or type(enum_type_id) ~= "number" or (
                enum_type_id ~= obs.enum.list.string 
                and enum_type_id ~= obs.enum.list.file and
                enum_type_id ~= obs.enum.list.url
            ) then
                enum_type_id= obs.enum.list.string
            end
            if not title or type(title) ~= "string" then
                title=""
            end
            if not unique_id or type(unique_id) ~= "string" or unique_id == ""  then
                unique_id= obs.utils.get_unique_id(20)
            end
            obs.utils.properties[unique_id]=obs.utils.obs_api_properties_patch(
                obslua.obs_properties_add_editable_list(properties_t, unique_id, title, enum_type_id, filter_string, default_path_string), 
            properties_t)
            return obs.utils.properties[unique_id]
        end
        function obs.script.input(p, unique_id, title, enum_type_id, callback)
            if not title or type(title) ~= "string" then
                title=""
            end
            if not unique_id or type(unique_id) ~= "string" or unique_id == ""  then
                unique_id= obs.utils.get_unique_id(20)
            end
            if not enum_type_id == nil or (
            enum_type_id ~= obs.enum.text.input and enum_type_id ~= obs.enum.text.textarea and
            enum_type_id ~= obs.enum.text.password) then
                enum_type_id= obs.enum.text.input
            end
            obs.utils.properties[unique_id]=obs.utils.obs_api_properties_patch(
                obslua.obs_properties_add_text(p, unique_id, title, enum_type_id), p
            )
            return obs.utils.properties[unique_id]
        end
        function obs.script.color(properties_t, unique_id, title)
            if not title or type(title) ~= "string" then
                title=""
            end
            if not unique_id or type(unique_id) ~= "string" or unique_id == ""  then
                unique_id= obs.utils.get_unique_id(20)
            end
            obs.utils.properties[unique_id]=obs.utils.obs_api_properties_patch(obslua.obs_properties_add_color_alpha(properties_t, unique_id, title), properties_t)
            return obs.utils.properties[unique_id]
        end
        function obs.script.number(properties_t, min, max,steps, unique_id, title, enum_number_type_id, enum_type_id)
            if not enum_number_type_id then
                enum_number_type_id= obs.enum.number.int
            end
            if not enum_type_id then
                enum_type_id= obs.enum.number.input
            end
            if not unique_id or type(unique_id) ~= "string" or unique_id == ""  then
                unique_id= obs.utils.get_unique_id(20)
            end
            local obj;if enum_type_id == obs.enum.number.slider then
                if enum_number_type_id == obs.enum.number.float then
                    obj= obs.utils.obs_api_properties_patch(obslua.obs_properties_add_float(
                        properties_t, unique_id, title, min, max,steps
                    ))
                else
                    obj= obs.utils.obs_api_properties_patch(obslua.obs_properties_add_int_slider(
                        properties_t, unique_id, title, min, max, steps
                    ))
                end
            else
                if enum_number_type_id == obs.enum.number.float then
                    obj= obs.utils.obs_api_properties_patch(obslua.obs_properties_add_float(
                        properties_t, unique_id, title, min, max,steps
                    ))
                else
                    obj= obs.utils.obs_api_properties_patch(obslua.obs_properties_add_int(
                        properties_t, unique_id, title, min, max, steps
                    ))
                end
            end
            if obj then
                obj["type"]= enum_number_type_id
            end
            obs.utils.properties[unique_id]=obj
            
            return obj
        end
        function obs.script.get(name)
            return obs.utils.properties[name]
        end
    -- [[ OBS SCRIPT PROPERTIES CUSTOM API END ]]
	-- [[ API UTILS ]]
        function obs.utils.obs_api_properties_patch(pp,pp_t, cb)
            -- if pp_t ~= nil and not obs.utils.properties[pp] then
            -- 	obs.utils.properties[pp]=pp_t;
            -- end
            local pp_unique_name= obslua.obs_property_name(pp)
            local obs_pp_t=pp; -- extra

            -- onchange [Event Handler]
            local __onchange_list={}

            local item=nil;local objText;local objInput;local objGlobal;objGlobal={
                cb=cb;disable=function()
                    obslua.obs_property_set_disabled(pp, true)
                    return nil
                end;enable=function()
                    obslua.obs_property_set_disabled(obs_pp_t, false)
                    return nil
                end;onchange=function(callback)
                    if type(callback) ~= "function" then
                        return false
                    end
                    table.insert(__onchange_list, callback)
                    return true
                end;hide= function()
                    obslua.obs_property_set_visible(obs_pp_t, false)
                end;show = function()
                    obslua.obs_property_set_visible(obs_pp_t, true)
                    return nil
                end;get= function()
                    return obs_pp_t
                end;hint= function(txt)
                    if txt == nil or type(txt) ~= "string" or txt == "" then
                        return obs_property_get_long_description(obs_pp_t)
                    end
                    item=obslua.obs_property_set_long_description(obs_pp_t, txt)
                    return nil
                end;free= function()
                    obs.utils.properties[pp_unique_name]=nil
                    obslua.obs_properties_remove_by_name(pp_t, pp_unique_name)
                    return true
                end;remove=function()
                    return objGlobal.free()
                end;data=pp;item=pp;title=function(txt)
                    if txt == nil or type(txt) ~= "string" then
                        return obslua.obs_property_get_description(pp)
                    end
                    obslua.obs_property_set_description(pp, txt)
                    return objGlobal
                end
            };objText={
                error=function(txt)
                    if txt == nil or type(txt) ~= "string" then
                        return obslua.obs_property_description(pp)
                    end

                    obslua.obs_property_text_set_info_type(pp, obslua.OBS_TEXT_INFO_ERROR)
                    obslua.obs_property_set_description(pp, txt)
                    return objText
                end;
                text=function(txt)
                    local id_name= obslua.obs_property_name(pp)
                    objText.type=obs.enum.text.default
                    obslua.obs_property_text_set_info_type(pp, objText.type)
                    if txt ~= nil and type(txt) == "string" then obslua.obs_property_set_description(pp, txt) end
                    return objText
                end;warn=function(txt)
                    local id_name= obslua.obs_property_name(pp)
                    local textarea_id= id_name .. "_obsapi_hotfix_textarea"
                    local input_id= id_name .. "_obsapi_hotfix_input"
                    local property= obs.script.get(pp_t, id_name)
                    local textarea_property= obs.script.get(pp_t, textarea_id)
                    local input_property= obs.script.get(pp_t, input_id)
                    objText.type=obs.enum.text.input
                    property.show();input_property.hide();textarea_property.hide()
                    objText.type=obs.enum.text.warn
                    obslua.obs_property_text_set_info_type(pp, objText.type)
                    if txt ~= nil and type(txt) == "string" then obslua.obs_property_set_description(pp, txt) end
                    return objText
                end;textarea=obs.expect(function(txt)
                    local id_name= obslua.obs_property_name(pp)
                    local textarea_id= id_name .. "_obsapi_hotfix_textarea"
                    local input_id= id_name .. "_obsapi_hotfix_input"
                    local property= obs.script.get(pp_t, id_name)
                    local textarea_property= obs.script.get(pp_t, textarea_id)
                    obs_pp_t=textarea_property.get()
                    local input_property= obs.script.get(pp_t, input_id)
                    objText.type=obs.enum.text.textarea
                    property.hide();input_property.hide();textarea_property.show()
                    if txt ~= nil and type(txt) == "string" then obs.utils.settings.str(textarea_id, txt) end
                    return objText
                end);type=-1
            };objInput={
                value=obs.expect(function(txt)
                    if txt ~= nil and type(txt) == "string" then obs.utils.settings.str(pp_unique_name, txt) end
                    return objInput
                end);type=-1
            };
            local objOption;objOption={
                item=nil;clear= function()
                    objOption.item=obslua.obs_property_list_clear(pp)
                    return objOption
                end;add={
                    str= function(title, id)
                        if id == nil or type(id) ~= "string" or id == "" then
                            --id= obs.utils.get_unique_id(20)
                            obslua.script_log(obslua.LOG_INFO, "[obs.script.options.str] id is nil or invalid!")
                            return objOption
                        end
                        objOption.item=obslua.obs_property_list_add_string(pp, title, id)
                        return objOption
                    end;int= function(title, id)
                        if id == nil or type(id) ~= "number" then
                            --id= obs.utils.get_unique_id(20)
                            obslua.script_log(obslua.LOG_INFO, "[obs.script.options.int] id is nil or invalid!")
                            return objOption
                        end
                        objOption.item=obslua.obs_property_list_add_int(pp, title, id)
                        return objOption
                    end;dbl=function(title, id)
                        if id == nil or type(id) ~= "number" then
                            --id= obs.utils.get_unique_id(20)
                            obslua.script_log(obslua.LOG_INFO, "[obs.script.options.dbl] id is nil or invalid!")
                            return objOption
                        end
                        objOption.item=obslua.obs_property_list_add_float(pp, title, id)
                        return objOption
                    end;bul=function(title, id)
                        if id == nil or type(id) ~= "boolean" then
                            id= obs.utils.get_unique_id(20)
                        end
                        objOption.item=obslua.obs_property_list_add_bool(pp, title, id)
                        return objOption
                    
                    end
                };cursor = function(index)
                    if index == nil or type(index) ~= "number" or index < 0 then
                        if type(index) == "string" then -- find the index by the id value
                            for i=0, obslua.obs_property_list_item_count(pp)-1 do
                                if obslua.obs_property_list_item_string(pp, i) == index then
                                    index= i
                                    break
                                end
                            end
                            if type(index) ~= "number" then
                                return nil
                            end
                        else
                            index= objOption.item;if  type(index) ~= "number" or index < 0 then
                                index=obslua.obs_property_list_item_count(pp)-1
                            end
                        end
                    end
                    local info_title;local info_id
                    info_title=obslua.obs_property_list_item_name(pp, index)
                    if obs.utils.properties.options[pp_unique_name] and obs.utils.properties.options[pp_unique_name].enum_format_id == obs.enum.options.string then
                        info_id= obslua.obs_property_list_item_string(pp, index)
                    elseif obs.utils.properties.options[pp_unique_name] and obs.utils.properties.options[pp_unique_name].enum_format_id == obs.enum.options.int then
                        info_id= obslua.obs_property_list_item_int(pp, index)
                    elseif obs.utils.properties.options[pp_unique_name] and obs.utils.properties.options[pp_unique_name].enum_format_id == obs.enum.options.float then
                        info_id= obslua.obs_property_list_item_float(pp, index)
                    elseif obs.utils.properties.options[pp_unique_name] and obs.utils.properties.options[pp_unique_name].enum_format_id == obs.enum.options.bool then
                        info_id= obslua.obs_property_list_item_bool(pp, index)
                    else
                        info_id= nil
                    end
                    local nn_obj=nil;nn_obj={
                        disable= function()
                            obslua.obs_property_list_item_disable(pp, index, true)
                            return nn_obj
                        end; enable= function()
                            obslua.obs_property_list_item_disable(pp, index, false)
                            return nn_obj
                        end;remove=function()
                            obslua.obs_property_list_item_remove(pp, index)
                            return true
                        end;title=info_title;value=info_id;index=index;
                        ret=function()
                            return objOption
                        end;isDisabled=function()
                            return obslua.obs_property_list_item_disabled(pp, index)
                        end
                    }
                    return nn_obj;
                end;current=function()
                    local current_selected_option=nil
                    if obs.utils.properties.options[pp_unique_name] and obs.utils.properties.options[pp_unique_name].enum_format_id == obs.enum.options.string then
                        current_selected_option= obs.utils.settings.str(pp_unique_name)
                    elseif obs.utils.properties.options[pp_unique_name] and obs.utils.properties.options[pp_unique_name].enum_format_id == obs.enum.options.int then
                        current_selected_option= obs.utils.settings.int(pp_unique_name)
                    elseif obs.utils.properties.options[pp_unique_name] and obs.utils.properties.options[pp_unique_name].enum_format_id == obs.enum.options.float then
                        current_selected_option= obs.utils.settings.float(pp_unique_name)
                    elseif obs.utils.properties.options[pp_unique_name] and obs.utils.properties.options[pp_unique_name].enum_format_id == obs.enum.options.bool then
                        current_selected_option= obs.utils.settings.bul(pp_unique_name)
                    end
                    return objOption.cursor(current_selected_option)
                end
            };local fr_rt= false
            local objButton;objButton={
                item=nil;click= function(callback)
                    if type(callback) ~= "function" then
                        obslua.script_log(obslua.LOG_ERROR, "[button.click] invalid callback type " .. type(callback) .. " expected function")
                        return objButton
                    end
                    
                    objButton.item=obslua.obs_property_set_modified_callback(pp,function(properties_t, property_t, obs_data_t)
                        
                        return callback(properties_t, property_t, obs.PairStack(obs_data_t))
                    end)
                    return objButton
                end;text= function(txt)
                    if txt == nil or type(txt) ~= "string" or txt == "" then
                        return obslua.obs_property_description(pp)
                    end
                    obslua.obs_property_set_description(pp, txt)
                    return objButton
                end;url=function(url)
                    if not url or type(url) ~= "string" or url == "" then
                        obslua.script_log(obslua.LOG_ERROR, "[button.url] invalid url type, expected string, got " .. type(url))
                        return objButton --obslua.obs_property_button_get_url(pp)
                    end
                    obslua.obs_property_button_set_url(pp, url)
                    return objButton
                end;type=function(button_type)
                    if button_type == nil or (button_type ~= obs.enum.button.url and button_type ~= obs.enum.button.default) then
                        obslua.script_log(obslua.LOG_ERROR, "[button.type] invalid type, expected obs.enum.button.url | obs.enum.button.default, got " .. type(button_type))
                        return objButton --obslua.obs_property_button_get_type(pp)
                    end
                    obslua.obs_property_button_set_type(pp, button_type)
                    return objButton
                end
            };
            local objGroup;objGroup={
            };local objBool;objBool={
                checked=function(bool_value)
                    if not obs.utils.settings then
                        obslua.script_log(obslua.LOG_ERROR, "[obs.utils.settings] is not set, please use 'script_load' to set it")
                        return nil
                    end
                    local property_id=obslua.obs_property_name(pp)
                    if bool_value == nil or type(bool_value) ~= "boolean" then
                        return obs.utils.settings.get_bul(property_id)
                    end
                    obs.utils.settings.bul(property_id, bool_value)
                    return objBool
                end;
            };local objColor;objColor={
                value= obs.expect(function(r_color, g_color, b_color, alpha_value)
                    if r_color == nil then
                        return obs.utils.settings.int(pp_unique_name)
                    end
                    if type(r_color) ~= "number" or type(g_color) ~= "number" or type(b_color) ~= "number" then
                        return false
                    end
                    if alpha_value == nil then
                        alpha_value=1
                    end
                    local color_value = bit.bor(
                        bit.lshift(alpha_value * 255, 24),
                        bit.lshift(b_color, 16),
                        bit.lshift(g_color, 8),
                        r_color
                    )
                    
                    --(alpha_value << 24) | (b_color << 16) | (g_color << 8) | r_color
                    obs.utils.settings.int(pp_unique_name, color_value)
                    return color_value
                end);type= obslua.OBS_PROPERTY_COLOR_ALPHA
            }local objList;objList={
                insert=function(value, selected, hidden)
                    if type(value) ~= "string" then
                        return objList
                    end
                    if type(selected) ~= "boolean" then
                        selected= false
                    end
                    if type(hidden) ~= "boolean" then
                        hidden= false
                    end
                    local unique_id= obs.utils.get_unique_id(20)
                    local obs_data_t= obs.PairStack()
                    obs_data_t.str("value", value)
                    obs_data_t.bul("selected", selected)
                    obs_data_t.bul("hidden", hidden)
                    obs_data_t.str("uuid", unique_id)
                    local obs_curr_data_t= obs.utils.settings.arr(pp_unique_name)
                    obs_curr_data_t.insert(obs_data_t.data)
                    obs_data_t.free();obs_curr_data_t.free()
                    return objList
                end,filter= function()
                    return obslua.obs_property_editable_list_filter(pp)
                end,default=function()
                    return obslua.obs_property_editable_list_default_path(pp)
                end,type=function()
                    return obslua.obs_property_editable_list_type(pp)
                end;
            };local objNumber;objNumber={
                suffix= function(text)
                    obslua.obs_property_float_set_suffix(pp, text)
                    obslua.obs_property_int_set_suffix(pp, text)
                    return objNumber
                end;value=function(value)
                    if objNumber.type == obs.enum.number.int then
                        obs.utils.settings.int(pp_unique_name, value)
                    elseif objNumber.type == obs.enum.number.float then
                        obs.utils.settings.dbl(pp_unique_name, value)
                    else
                        return nil
                    end
                    return value
                end;type=nil
            }


            local property_type= obslua.obs_property_get_type(pp)
            -- [[ ON-CHANGE EVENT HANDLE FOR ANY KIND OF USER INTERACTIVE INPUT ]]
            if property_type == obslua.OBS_PROPERTY_COLOR or property_type == obslua.OBS_PROPERTY_COLOR_ALPHA or 
            property_type == obslua.OBS_PROPERTY_BOOL or property_type == obslua.OBS_PROPERTY_LIST or 
            property_type == obslua.OBS_PROPERTY_EDITABLE_LIST or property_type == obslua.OBS_PROPERTY_PATH or
            (property_type == obslua.OBS_PROPERTY_TEXT and (
                obslua.obs_property_text_type(pp) == obs.enum.text.textarea or 
                obslua.obs_property_text_type(pp) == obs.enum.text.input or 
                obslua.obs_property_text_type(pp) == obs.enum.text.password
            )) then
                obslua.obs_property_set_modified_callback(obs_pp_t, function(properties_t, property_t, settings)
                    settings=obs.PairStack(settings)
                    local pp_unique_name= obslua.obs_property_name(property_t)
                    local current_value;property_type= obslua.obs_property_get_type(property_t)
                    if property_type == obslua.OBS_PROPERTY_BOOL then
                        current_value= settings.bul(pp_unique_name)
                    elseif property_type == obslua.OBS_PROPERTY_TEXT or  
                    property_type == obslua.OBS_PROPERTY_PATH or 
                    property_type == obslua.OBS_PROPERTY_BUTTON then
                        current_value= settings.str(pp_unique_name)
                    elseif property_type == obslua.OBS_PROPERTY_INT or property_type == obslua.OBS_PROPERTY_COLOR_ALPHA or property_type == obslua.OBS_PROPERTY_COLOR then
                        current_value= settings.int(pp_unique_name)
                    elseif property_type == obslua.OBS_PROPERTY_FLOAT then
                        current_value= settings.dbl(pp_unique_name)
                    elseif property_type == obslua.OBS_PROPERTY_LIST then

                        if obs.utils.properties.options[pp_unique_name].type == obs.enum.options.string then
                            current_value= settings.str(pp_unique_name)

                        elseif obs.utils.properties.options[pp_unique_name].type == obs.enum.options.int then
                            current_value= settings.int(pp_unique_name)
                        elseif obs.utils.properties.options[pp_unique_name].type == obs.enum.options.float then
                            current_value= settings.dbl(pp_unique_name)
                        elseif obs.utils.properties.options[pp_unique_name].type == obs.enum.options.bool then
                            current_value= settings.bul(pp_unique_name)
                        end
                    elseif property_type == obslua.OBS_PROPERTY_FONT then
                        current_value= settings.obj(pp_unique_name)
                    elseif property_type == obslua.OBS_PROPERTY_EDITABLE_LIST then
                        current_value= settings.arr(pp_unique_name)
                    end
                    
                    for _, vclb in pairs(__onchange_list) do
                        vclb(current_value, obs.script.get(obslua.obs_property_name(property_t)), properties_t, settings)
                    end
                    if type(current_value) == "table" then
                        current_value.free()
                    end
                    return true
                end);
            end


            if property_type == obslua.OBS_PROPERTY_GROUP then
                obs.utils.table.append(objGroup, objGlobal)
                return objGroup;
            elseif property_type == obslua.OBS_PROPERTY_EDITABLE_LIST then
                obs.utils.table.append(objList, objGlobal)
                return objList
            elseif property_type == obslua.OBS_PROPERTY_LIST then
                obs.utils.table.append(objOption, objGlobal)
                return objOption;
            elseif property_type == obslua.OBS_PROPERTY_INT or property_type == obslua.OBS_PROPERTY_FLOAT then
                obs.utils.table.append(objNumber, objGlobal)
                return objNumber
            elseif property_type == obslua.OBS_PROPERTY_BUTTON then
                obs.utils.table.append(objButton, objGlobal)
                return objButton
            elseif property_type == obslua.OBS_PROPERTY_COLOR_ALPHA or property_type == obslua.OBS_PROPERTY_COLOR then
                obs.utils.table.append(objColor, objGlobal)
                return objColor
            elseif property_type == obslua.OBS_PROPERTY_TEXT then
                local obj_enum_type_id= obslua.obs_property_text_type(pp)
                if obj_enum_type_id == obs.enum.text.textarea or 
                obj_enum_type_id == obs.enum.text.input or 
                obj_enum_type_id == obs.enum.text.password then
                    objInput.type= obj_enum_type_id
                    obs.utils.table.append(objInput, objGlobal)
                    return objInput;
                else
                    objText.type= obj_enum_type_id
                    obs.utils.table.append(objText, objGlobal)
                    return objText;
                end
            elseif property_type == obslua.OBS_PROPERTY_BOOL then
                obs.utils.table.append(objBool, objGlobal)
                return objBool;
            else
                return objGlobal;
            end
        end
        function obs.utils.get_unique_id(rs, i, mpc, cmpc)
            local chars= "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
            if i == nil then
                i= true;
            end
            if mpc == nil or type(mpc) ~= "string" then
                mpc= tostring(os.time());
                mpc=obs.utils.get_unique_id(rs, false, mpc, true)
            elseif cmpc == true then
                chars=mpc
            end
            
            local index= math.random(1, #chars)
            local c= chars:sub(index, index)
            if c == nil then
                c=""
            end
            if rs <= 0 then
                return c;
            end
            local val= obs.utils.get_unique_id(rs - 1,false, mpc, cmpc)
            
            if i == true and mpc ~= nil and type(mpc) == "string" and #val > 1 then
                val= val .. "_" .. mpc
            end
            return c .. val
        end
        function obs.utils.table.append(tb, vv)
        for k, v in pairs(vv) do
            if type(v) == "function" then
                local old_v = v
                v = function(...)
                    local retValue= old_v(...)
                    if retValue== nil then
                        return tb;
                    end
                    return retValue;
                end
            end
            if type(k) == "string" then
            tb[k]= v;
            else
            table.insert(tb, k, v)
            end
        end
        end
        function obs.utils.json_to_table(str)
            local position = 1
            local function skip_whitespace()
                local _, e = str:find("^[ \n\r\t]*", position)
                position = (e or position - 1) + 1
            end
            local function parse_value()
                skip_whitespace()

                local char = str:sub(position, position)

                -- Object
                if char == '{' then
                    position = position + 1
                    local obj = {}
                    skip_whitespace()
                    if str:sub(position, position) == '}' then
                        position = position + 1
                        return obj
                    end
                    while true do
                        skip_whitespace()
                        local key = parse_value()
                        skip_whitespace()
                        assert(str:sub(position, position) == ':', "Expected ':' after key")
                        position = position + 1
                        obj[key] = parse_value()
                        skip_whitespace()
                        local next_char = str:sub(position, position)
                        if next_char == '}' then
                            position = position + 1
                            break
                        end
                        assert(next_char == ',', "Expected ',' or '}' in object")
                        position = position + 1
                    end
                    return obj

                -- Array
                elseif char == '[' then
                    position = position + 1
                    local arr = {}
                    skip_whitespace()
                    if str:sub(position, position) == ']' then
                        position = position + 1
                        return arr
                    end
                    while true do
                        arr[#arr + 1] = parse_value()
                        skip_whitespace()
                        local next_char = str:sub(position, position)
                        if next_char == ']' then
                            position = position + 1
                            break
                        end
                        assert(next_char == ',', "Expected ',' or ']' in array")
                        position = position + 1
                    end
                    return arr

                -- String
                elseif char == '"' then
                    position = position + 1
                    local start = position
                    while true do
                        local c = str:sub(position, position)
                        if c == '"' then
                            local s = str:sub(start, position - 1)
                            position = position + 1
                            return s
                        elseif c == '\\' then
                            position = position + 2 -- Skip escaped char
                        elseif c == '' then
                            error("Unterminated string")
                        else
                            position = position + 1
                        end
                    end

                -- Number
                elseif char:match("[%d%-]") then
                    local num_str
                    num_str, position = str:match("^([-0-9.eE]+)()", position)
                    local num = tonumber(num_str)
                    assert(num ~= nil, "Invalid number: " .. tostring(num_str))
                    return num

                -- True / False / Null
                elseif str:sub(position, position + 3) == "true" then
                    position = position + 4
                    return true
                elseif str:sub(position, position + 4) == "false" then
                    position = position + 5
                    return false
                elseif str:sub(position, position + 3) == "null" then
                    position = position + 4
                    return nil
                end

                error("Unexpected character at position " .. position .. ": " .. tostring(char))
            end
            return parse_value()
        end
    -- [[ API UTILS END ]]
-- [[ OBS CUSTOM API END ]]