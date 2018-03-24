obs = obslua
bit = require("bit")

SETTING_HUE_STEPS = 'hue_steps'
SETTING_VALUE_STEPS = 'value_steps'

TEXT_HUE_STEPS = 'Hue Steps'
TEXT_VALUE_STEPS = 'Value Steps'

source_def = {}
source_def.id = 'filter-toon'
source_def.type = obs.OBS_SOURCE_TYPE_FILTER
source_def.output_flags = bit.bor(obs.OBS_SOURCE_VIDEO)

function set_render_size(filter)
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

source_def.get_name = function()
    return "Toon"
end

source_def.create = function(settings, source)
    local effect_path = script_path() .. 'filter-toon/filter-toon.effect'

    filter = {}
    filter.params = {}
    filter.context = source

    set_render_size(filter)

    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create_from_file(effect_path, nil)
    if filter.effect ~= nil then
        filter.params.hue_steps = obs.gs_effect_get_param_by_name(filter.effect, 'hue_steps')
        filter.params.value_steps = obs.gs_effect_get_param_by_name(filter.effect, 'value_steps')
    end
    obs.obs_leave_graphics()
    
    if filter.effect == nil then
        source_def.destroy(filter)
        return nil
    end

    source_def.update(filter, settings)
    return filter
end

source_def.destroy = function(filter)
    if filter.effect ~= nil then
        obs.obs_enter_graphics()
        obs.gs_effect_destroy(filter.effect)
        obs.obs_leave_graphics()
    end
end

source_def.get_width = function(filter)
    return filter.width
end

source_def.get_height = function(filter)
    return filter.height
end

source_def.update = function(filter, settings)
    filter.hue_steps = obs.obs_data_get_int(settings, SETTING_HUE_STEPS)
    filter.value_steps = obs.obs_data_get_int(settings, SETTING_VALUE_STEPS)

    set_render_size(filter)
end

source_def.video_render = function(filter, effect)
    obs.obs_source_process_filter_begin(filter.context, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING)

    obs.gs_effect_set_int(filter.params.hue_steps, filter.hue_steps)
    obs.gs_effect_set_int(filter.params.value_steps, filter.value_steps)

    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

source_def.get_properties = function(settings)
    props = obs.obs_properties_create()

    obs.obs_properties_add_int_slider(props, SETTING_HUE_STEPS, TEXT_HUE_STEPS, 1, 10, 1)
    obs.obs_properties_add_int_slider(props, SETTING_VALUE_STEPS, TEXT_VALUE_STEPS, 1, 10, 1)

    return props
end

source_def.get_defaults = function(settings)
    obs.obs_data_set_default_int(settings, SETTING_HUE_STEPS, 5)
    obs.obs_data_set_default_int(settings, SETTING_VALUE_STEPS, 5)
end

source_def.video_tick = function(filter, seconds)
    set_render_size(filter)
end

obs.obs_register_source(source_def)
