obs = obslua
bit = require("bit")

SETTING_THRESHOLD = 'threshold'
SETTING_COLOR = 'color'

TEXT_THRESHOLD = 'Edge Threshold'
TEXT_COLOR = 'Edge Color'

source_def = {}
source_def.id = 'filter-edges'
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
    width = width == 0 and 1 or width
    height = height == 0 and 1 or height
    filter.pixel_size.x = 1.0 / width
    filter.pixel_size.y = 1.0 / height
end

source_def.get_name = function()
    return "Edge Detection"
end

source_def.create = function(settings, source)
    local effect_path = script_path() .. 'filter-edges/filter-edges.effect'

    filter = {}
    filter.params = {}
    filter.context = source
    filter.pixel_size = obs.vec2()
    filter.color = obs.vec4()

    set_render_size(filter)

    obs.obs_enter_graphics()
    filter.effect = obs.gs_effect_create_from_file(effect_path, nil)
    if filter.effect ~= nil then
        filter.params.pixel_size = obs.gs_effect_get_param_by_name(filter.effect, 'pixel_size')
        filter.params.threshold = obs.gs_effect_get_param_by_name(filter.effect, 'threshold')
        filter.params.edge_color = obs.gs_effect_get_param_by_name(filter.effect, 'edge_color')
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
    color = obs.obs_data_get_int(settings, SETTING_COLOR)
    filter.threshold = obs.obs_data_get_double(settings, SETTING_THRESHOLD)

    obs.vec4_from_rgba(filter.color, color)

    set_render_size(filter)
end

source_def.video_render = function(filter, effect)
    obs.obs_source_process_filter_begin(filter.context, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING)

    obs.gs_effect_set_vec2(filter.params.pixel_size, filter.pixel_size)
    obs.gs_effect_set_float(filter.params.threshold, filter.threshold)
    obs.gs_effect_set_vec4(filter.params.edge_color, filter.color)

    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.width, filter.height)
end

source_def.get_properties = function(settings)
    props = obs.obs_properties_create()

    obs.obs_properties_add_color(props, SETTING_COLOR, TEXT_COLOR)
    obs.obs_properties_add_float_slider(props, SETTING_THRESHOLD, TEXT_THRESHOLD, 0, 1, 0.01);

    return props
end

source_def.get_defaults = function(settings)
    obs.obs_data_set_default_int(settings, SETTING_COLOR, 0xFF000000)
    obs.obs_data_set_default_double(settings, SETTING_THRESHOLD, 0.3);
end

source_def.video_tick = function(filter, seconds)
    set_render_size(filter)
end

obs.obs_register_source(source_def)
