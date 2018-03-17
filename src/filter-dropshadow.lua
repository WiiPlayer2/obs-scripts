obs = obslua
bit = require("bit")

SETTING_SHADOW_COLOR = 'shadow_color'
SETTING_OFFSET_X = 'offset_x'
SETTING_OFFSET_Y = 'offset_y'
SETTING_HIDE_IMAGE = 'hide_image'
SETTING_HIDE_SHADOW = 'hide_shadow'

TEXT_SHADOW_COLOR = 'Shadow Color'
TEXT_OFFSET_X = 'Shadow Offset X'
TEXT_OFFSET_Y = 'Shadow Offset Y'
TEXT_HIDE_IMAGE = 'Hide Image'
TEXT_HIDE_SHADOW = 'Hide Shadow'

source_def = {}
source_def.id = "filter-dropshadow"
source_def.type = obs.OBS_SOURCE_TYPE_FILTER
source_def.output_flags = bit.bor(obs.OBS_SOURCE_VIDEO)

function vec4_from_rgba(rgba)
    local t = {}
    for i = 0, 3 do
        t[i+1] = bit.band(bit.rshift(rgba , i * 8), 0xff)
    end
    return t
end

function calculate_sizes(filter)
    filter.render_width = filter.target_width + math.abs(filter.offset.x)
    filter.render_height = filter.target_height + math.abs(filter.offset.y)

    obs.vec2_set(filter.uv_mul_val, 1.0, 1.0)
    if filter.render_width ~= 0 and filter.render_height ~= 0 then
        filter.uv_mul_val.x = filter.target_width ~= 0 and filter.render_width / filter.target_width or 1.0
        filter.uv_mul_val.y = filter.target_height ~= 0 and filter.render_height / filter.target_height or 1.0

        filter.uv_offset.x = filter.offset.x / filter.target_width
        filter.uv_offset.y = filter.offset.y / filter.target_height
    end

    obs.vec2_zero(filter.uv_add_val)
    if filter.offset.x < 0 and filter.render_width ~= 0 then
        filter.uv_add_val.x = filter.offset.x / filter.render_width
    end
    if filter.offset.y < 0 and filter.render_height ~= 0 then
        filter.uv_add_val.y = filter.offset.y / filter.render_height
    end
end

source_def.get_name = function()
    return 'Dropshadow'
end

source_def.destroy = function(filter)
    if filter.effect ~= nil then
        obs.obs_enter_graphics()
        obs.gs_effect_destroy(filter.effect)
        obs.obs_leave_graphics()
    end
end

source_def.update = function(filter, settings)
    shadow_color = obs.obs_data_get_int(settings, SETTING_SHADOW_COLOR)
    offset_x = obs.obs_data_get_int(settings, SETTING_OFFSET_X)
    offset_y = obs.obs_data_get_int(settings, SETTING_OFFSET_Y)
    filter.hide_image = obs.obs_data_get_bool(settings, SETTING_HIDE_IMAGE)
    filter.hide_shadow = obs.obs_data_get_bool(settings, SETTING_HIDE_SHADOW)

    obs.vec2_set(filter.offset, offset_x, offset_y)
    obs.vec4_from_rgba(filter.shadow_color, shadow_color)

    calculate_sizes(filter)
end

source_def.create = function(settings, source)
    filter = {}
    effect_path  = script_path() .. 'filter-dropshadow/filter-dropshadow.effect'

    filter.context = source
    filter.shadow_color = obs.vec4()
    filter.offset = obs.vec2()
    filter.uv_offset = obs.vec2()
    filter.uv_mul_val = obs.vec2()
    filter.uv_add_val = obs.vec2()

    obs.obs_enter_graphics()

    filter.effect = obs.gs_effect_create_from_file(effect_path, nil)
    if filter.effect ~= nil then
        filter.shadow_color_param = obs.gs_effect_get_param_by_name(filter.effect, "shadow_color")
        filter.uv_offset_param = obs.gs_effect_get_param_by_name(filter.effect, "uv_offset")
        filter.uv_mul_val_param = obs.gs_effect_get_param_by_name(filter.effect, "uv_mul_val")
        filter.uv_add_val_param = obs.gs_effect_get_param_by_name(filter.effect, "uv_add_val")
        filter.hide_image_param = obs.gs_effect_get_param_by_name(filter.effect, "hide_image")
        filter.hide_shadow_param = obs.gs_effect_get_param_by_name(filter.effect, "hide_shadow")
    end

    obs.obs_leave_graphics()

    if filter.effect == nil then
        source_def.destroy(filter)
        return nil
    end

    filter.target_height = 0
    filter.target_width = 0

    source_def.update(filter, settings)
    return filter
end

source_def.get_width = function(filter)
    return filter.render_width
end

source_def.get_height = function(filter)
    return filter.render_height
end

source_def.video_render = function(filter, effect)
    obs.obs_source_process_filter_begin(filter.context, obs.GS_RGBA, obs.OBS_NO_DIRECT_RENDERING)

    obs.gs_effect_set_vec4(filter.shadow_color_param, filter.shadow_color)
    obs.gs_effect_set_vec2(filter.uv_offset_param, filter.uv_offset)
    obs.gs_effect_set_vec2(filter.uv_mul_val_param, filter.uv_mul_val)
    obs.gs_effect_set_vec2(filter.uv_add_val_param, filter.uv_add_val)
    obs.gs_effect_set_bool(filter.hide_image_param, filter.hide_image)
    obs.gs_effect_set_bool(filter.hide_shadow_param, filter.hide_shadow)

    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.render_width, filter.render_height)
end

source_def.get_properties = function(settings)
    props = obs.obs_properties_create()

    obs.obs_properties_add_color(props, SETTING_SHADOW_COLOR, TEXT_SHADOW_COLOR)
    obs.obs_properties_add_int(props, SETTING_OFFSET_X, TEXT_OFFSET_X, -8192, 8192, 1)
    obs.obs_properties_add_int(props, SETTING_OFFSET_Y, TEXT_OFFSET_Y, -8192, 8192, 1)
    obs.obs_properties_add_bool(props, SETTING_HIDE_IMAGE, TEXT_HIDE_IMAGE)
    obs.obs_properties_add_bool(props, SETTING_HIDE_SHADOW, TEXT_HIDE_SHADOW)

    return props
end

source_def.get_defaults = function(settings)
    obs.obs_data_set_default_int(settings, SETTING_SHADOW_COLOR, 0x80000000)
    obs.obs_data_set_default_int(settings, SETTING_OFFSET_X, 30)
    obs.obs_data_set_default_int(settings, SETTING_OFFSET_Y, 30)
    obs.obs_data_set_default_bool(settings, SETTING_HIDE_IMAGE, false)
    obs.obs_data_set_default_bool(settings, SETTING_HIDE_SHADOW, false)
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

    filter.target_width = width
    filter.target_height = height

    calculate_sizes(filter)
end

obs.obs_register_source(source_def)
