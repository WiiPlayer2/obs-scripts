obs = obslua
bit = require("bit")

SETTING_EFFECT_PATH = 'effect_path'
SETTING_RELOAD = 'reload'

TEXT_EFFECT_PATH = 'Effect File'
TEXT_RELOAD = 'Reload Effect File'

EFFECT_FILE_FILTER = 'Effect File (*.effect);; All Files (*.*)'

source_def = {}
source_def.id = 'filter-custom'
source_def.type = obs.OBS_SOURCE_TYPE_FILTER
source_def.output_flags = bit.bor(obs.OBS_SOURCE_VIDEO)

function get_random()
    return 'tmp'
end

function read_file(path)
    local f, err = io.open(path)
    if f == nil then
        print(err)
        return ''
    end
    local content = f:read('*a')
    f:close()
    return content
end

function reload_filter(filter)
    obs.obs_enter_graphics()
    if filter.effect ~= nil then
        print('destroying filter ' .. tostring(filter.effect))
        obs.gs_effect_destroy(filter.effect)
    end
    filter.effect = obs.gs_effect_create(read_file(filter.effect_path), nil, nil)
    if filter.effect == nil then
        print('failed to load effect ' .. filter.effect_path)
    else
        print('loaded effect ' .. filter.effect_path .. ' (' .. tostring(filter.effect) .. ')')
    end
    obs.obs_leave_graphics()
end

source_def.get_name = function()
    return 'Custom Filter'
end

source_def.update = function(filter, settings)
    filter.effect_path = obs.obs_data_get_string(settings, SETTING_EFFECT_PATH)

    reload_filter(filter)
end

source_def.destroy = function(filter)
    if filter.effect ~= nil then
        obs.obs_enter_graphics()
        obs.gs_effect_destroy(filter.effect)
        obs.obs_leave_graphics()
    end
end

source_def.create = function(settings, source)
    filter = {}
    filter.context = source
    filter.width = 0
    filter.height = 0
    filter.effect_path = ''

    obs.obs_enter_graphics()
    filter.fallback_effect = obs.gs_effect_create_from_file(script_path() .. 'filter-custom/filter-custom-fallback.effect', nil)
    obs.obs_leave_graphics()

    source_def.update(filter, settings)

    return filter
end

source_def.get_width = function(filter)
    return filter.width
end

source_def.get_height = function(filter)
    return filter.height
end

source_def.video_render = function(filter, effect)
    local effect = filter.effect
    if filter.effect == nil then
        effect = filter.fallback_effect
    end

    if effect ~= nil then
        obs.obs_source_process_filter_begin(filter.context, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING)
        obs.obs_source_process_filter_end(filter.context, effect, filter.width, filter.height)
    end
end

source_def.get_properties = function(filter)
    props = obs.obs_properties_create()

    obs.obs_properties_add_path(props, SETTING_EFFECT_PATH, TEXT_EFFECT_PATH, obs.OBS_PATH_FILE, EFFECT_FILE_FILTER, nil)
    obs.obs_properties_add_button(props, SETTING_RELOAD, TEXT_RELOAD, function() reload_filter(filter) end)

    return props
end

source_def.video_tick = function(filter, seconds)
    target = obs.obs_filter_get_target(filter.context)

    local width, height
    if target == nil then
        width = 0
        height = 0
    else
        width = obs.obs_source_get_base_width(target)
        height = obs.obs_source_get_base_height(target)
    end

    filter.width = width
    filter.height = height
end

obs.obs_register_source(source_def)
