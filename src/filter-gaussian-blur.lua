obs = obslua
bit = require("bit")

MAX_KERNEL_SIZE = 16 -- max.: 3 * MAX_SIGMA
MAX_SIGMA = 10.0

SETTING_KERNEL_SIZE = 'kernel_size'
SETTING_SIGMA = 'sigma'
SETTING_USE_MASK = 'use_mask'
SETTING_INVERT_MASK = 'invert_mask'
SETTING_MASK_IMAGE = 'mask_image'
SETTING_PIXEL_SKIP = 'pixel_skip'

TEXT_KERNEL_SIZE = 'Kernel Size'
TEXT_SIGMA = 'Sigma'
TEXT_USE_MASK = 'Use Blur Mask'
TEXT_INVERT_MASK = 'Invert Blur Mask'
TEXT_MASK = 'Blur Mask Image (Alpha)'
TEXT_PIXEL_SKIP = 'Pixel Skip Factor'

IMAGE_FILTER = 'Images (*.bmp *.jpg *.jpeg *.tga *.gif *.png);; All Files (*.*)'

source_def = {}
source_def.id = 'filter_gaussian_blur'
source_def.type = obs.OBS_SOURCE_TYPE_FILTER
source_def.output_flags = bit.bor(obs.OBS_SOURCE_VIDEO)

function gaussian(sigma, x)
    factor = 1.0 / math.sqrt(2 * math.pi * sigma * sigma)
    exponent = -1 * (x * x) / (2 * sigma * sigma);
    return factor * math.exp(exponent)
end

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

    filter.render_width = width
    filter.render_height = height
    if width == 0 then
        width = 1
    end
    if height == 0 then
        height = 1
    end
    filter.pixel_size.x = filter.pixel_skip / width
    filter.pixel_size.y = filter.pixel_skip / height
end

source_def.get_name = function()
    return 'Gaussian Blur'
end

source_def.destroy = function(filter)
    if filter.effect ~= nil then
        obs.obs_enter_graphics()
        obs.gs_effect_destroy(filter.effect)
        obs.obs_leave_graphics()
    end
end

source_def.update = function(filter, settings)
    local kernel_size = obs.obs_data_get_int(settings, SETTING_KERNEL_SIZE)
    filter.kernel_size = math.ceil(kernel_size / 2)
    filter.sigma = obs.obs_data_get_double(settings, SETTING_SIGMA)
    filter.use_mask = obs.obs_data_get_bool(settings, SETTING_USE_MASK)
    filter.invert_mask = obs.obs_data_get_bool(settings, SETTING_INVERT_MASK)
    filter.pixel_skip = obs.obs_data_get_int(settings, SETTING_PIXEL_SKIP)
    local mask_image_path = obs.obs_data_get_string(settings, SETTING_MASK_IMAGE)

    local kernel = {}
    local sum = 0.0
    for i = 1, filter.kernel_size do
        kernel[i] = gaussian(filter.sigma, i - 1)
        sum = sum + kernel[i] + kernel[i]
    end
    for i = filter.kernel_size + 1, MAX_KERNEL_SIZE do
        kernel[i] = 0.0
    end
    sum = sum - kernel[1]
    local norm = 1.0 / sum
    for i = 1, MAX_KERNEL_SIZE do
        kernel[i] = kernel[i] * norm
        print(kernel[i])
    end

    obs.vec4_set(filter.kernel0, kernel[1], kernel[2], kernel[3], kernel[4])
    obs.vec4_set(filter.kernel1, kernel[5], kernel[6], kernel[7], kernel[8])
    obs.vec4_set(filter.kernel2, kernel[9], kernel[10], kernel[11], kernel[12])
    obs.vec4_set(filter.kernel3, kernel[13], kernel[14], kernel[15], kernel[16])

    if filter.use_mask then
        obs.obs_enter_graphics()
        obs.gs_image_file_free(filter.mask_image)
        obs.obs_leave_graphics()

        obs.gs_image_file_init(filter.mask_image, mask_image_path)

        obs.obs_enter_graphics()
        obs.gs_image_file_init_texture(filter.mask_image)
        obs.obs_leave_graphics()

        if not filter.mask_image.loaded then
            print("failed to load texture " .. mask_image_path);
        end
    end

    set_render_size(filter)
end

source_def.create = function(settings, source)
    filter = {}
    effect_path = script_path() .. 'filter-gaussian-blur/filter-gaussian-blur.effect'

    filter.context = source

    filter.mask_image = obs.gs_image_file()

    filter.pixel_size = obs.vec2()
    filter.pixel_skip = 1

    filter.kernel_size = 4
    filter.kernel0 = obs.vec4()
    filter.kernel1 = obs.vec4()
    filter.kernel2 = obs.vec4()
    filter.kernel3 = obs.vec4()

    set_render_size(filter)
    
    obs.obs_enter_graphics()

    filter.effect = obs.gs_effect_create_from_file(effect_path, nil)
    if filter.effect ~= nil then
        filter.mask_param = obs.gs_effect_get_param_by_name(filter.effect, 'mask')
        filter.use_mask_param = obs.gs_effect_get_param_by_name(filter.effect, 'use_mask')
        filter.invert_mask_param = obs.gs_effect_get_param_by_name(filter.effect, 'invert_mask')

        filter.pixel_size_param = obs.gs_effect_get_param_by_name(filter.effect, 'pixel_size')

        filter.kernel0_param = obs.gs_effect_get_param_by_name(filter.effect, 'kernel0')
        filter.kernel1_param = obs.gs_effect_get_param_by_name(filter.effect, 'kernel1')
        filter.kernel2_param = obs.gs_effect_get_param_by_name(filter.effect, 'kernel2')
        filter.kernel3_param = obs.gs_effect_get_param_by_name(filter.effect, 'kernel3')
        filter.kernel_size_param = obs.gs_effect_get_param_by_name(filter.effect, 'kernel_size')
    end

    obs.obs_leave_graphics()

    if filter.effect == nil then
        source_def.destroy(filter)
        return nil
    end

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

    obs.gs_effect_set_texture(filter.mask_param, filter.mask_image.texture)
    obs.gs_effect_set_bool(filter.use_mask_param, filter.use_mask)
    obs.gs_effect_set_bool(filter.invert_mask_param, filter.invert_mask)

    obs.gs_effect_set_vec2(filter.pixel_size_param, filter.pixel_size)

    obs.gs_effect_set_vec4(filter.kernel0_param, filter.kernel0)
    obs.gs_effect_set_vec4(filter.kernel1_param, filter.kernel1)
    obs.gs_effect_set_vec4(filter.kernel2_param, filter.kernel2)
    obs.gs_effect_set_vec4(filter.kernel3_param, filter.kernel3)
    obs.gs_effect_set_int(filter.kernel_size_param, filter.kernel_size)

    obs.obs_source_process_filter_end(filter.context, filter.effect, filter.render_width, filter.render_height)
end

source_def.get_properties = function(settings)
    props = obs.obs_properties_create()

    obs.obs_properties_add_int_slider(props, SETTING_KERNEL_SIZE, TEXT_KERNEL_SIZE, 1, MAX_KERNEL_SIZE * 2 - 1, 2)
    obs.obs_properties_add_float_slider(props, SETTING_SIGMA, TEXT_SIGMA, 1.0, MAX_SIGMA, 0.01)
    obs.obs_properties_add_int_slider(props, SETTING_PIXEL_SKIP, TEXT_PIXEL_SKIP, 1, 128, 1)
    obs.obs_properties_add_bool(props, SETTING_USE_MASK, TEXT_USE_MASK)
    obs.obs_properties_add_bool(props, SETTING_INVERT_MASK, TEXT_INVERT_MASK)
    obs.obs_properties_add_path(props, SETTING_MASK_IMAGE, TEXT_MASK_IMAGE, obs.OBS_PATH_FILE, IMAGE_FILTER, nil)

    return props
end

source_def.get_defaults = function(settings)
    obs.obs_data_set_default_int(settings, SETTING_KERNEL_SIZE, 3)
    obs.obs_data_set_default_double(settings, SETTING_SIGMA, 1.0)
    obs.obs_data_set_default_bool(settings, SETTING_USE_MASK, false)
    obs.obs_data_set_default_bool(settings, SETTING_INVERT_MASK, false)
    obs.obs_data_set_default_int(settings, SETTING_PIXEL_SKIP, 1)
end

source_def.video_tick = function(filter, seconds)
    set_render_size(filter)
end

obs.obs_register_source(source_def)
