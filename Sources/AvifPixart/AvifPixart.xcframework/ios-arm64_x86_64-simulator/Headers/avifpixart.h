#include <cstdarg>
#include <cstdint>
#include <cstdlib>
#include <ostream>
#include <new>

enum class AvifYCgCoRType {
  Ro,
  Re,
};

enum class YuvMatrix {
  Bt601,
  Bt709,
  Bt2020,
  Identity,
  YCgCo,
};

enum class YuvRange {
  Tv,
  Pc,
};

enum class YuvType {
  Yuv420,
  Yuv422,
  Yuv444,
};

extern "C" {

void pixart_rgba_u16_to_ra30(const uint16_t *source_u16,
                             uint32_t u16_stride,
                             uint8_t *ar30_dst,
                             uint32_t ar30_stride,
                             uint32_t bit_depth,
                             uint32_t width,
                             uint32_t height);

void pixart_rgb_u16_to_ra30(const uint16_t *source_u16,
                            uint32_t u16_stride,
                            uint8_t *ar30_dst,
                            uint32_t ar30_stride,
                            uint32_t bit_depth,
                            uint32_t width,
                            uint32_t height);

void pixart_rgba_u16_to_f16(const uint16_t *source_f16,
                            uint32_t f16_stride,
                            uint16_t *target_f16,
                            uint32_t target_f16_stride,
                            uint32_t bit_depth,
                            uint32_t width,
                            uint32_t height);

void pixart_rgb_u16_to_f16(const uint16_t *source_f16,
                           uint32_t f16_stride,
                           uint16_t *target_f16,
                           uint32_t target_f16_stride,
                           uint32_t bit_depth,
                           uint32_t width,
                           uint32_t height);

void pixart_rgba8_to_yuv8(uint8_t *y_plane,
                          uint32_t y_stride,
                          uint8_t *u_plane,
                          uint32_t u_stride,
                          uint8_t *v_plane,
                          uint32_t v_stride,
                          const uint8_t *rgba,
                          uint32_t rgba_stride,
                          uint32_t width,
                          uint32_t height,
                          YuvRange range,
                          YuvMatrix yuv_matrix,
                          YuvType yuv_type);

void pixart_rgba8_to_y08(uint8_t *y_plane,
                         uint32_t y_stride,
                         const uint8_t *rgba,
                         uint32_t rgba_stride,
                         uint32_t width,
                         uint32_t height,
                         YuvRange range,
                         YuvMatrix yuv_matrix);

void pixart_rgba8_to_icgco_r10(uint16_t *y_plane,
                               uint32_t y_stride,
                               uint16_t *u_plane,
                               uint32_t u_stride,
                               uint16_t *v_plane,
                               uint32_t v_stride,
                               const uint8_t *rgba,
                               uint32_t rgba_stride,
                               uint32_t width,
                               uint32_t height,
                               YuvRange range,
                               AvifYCgCoRType r_type,
                               YuvType yuv_type);

void pixart_scale_plane_u16(const uint16_t *src,
                            uintptr_t src_stride,
                            uint32_t width,
                            uint32_t height,
                            uint16_t *dst,
                            uint32_t new_width,
                            uint32_t new_height,
                            uintptr_t bit_depth);

void pixart_scale_plane_u8(const uint8_t *src,
                           uint32_t src_stride,
                           uint32_t width,
                           uint32_t height,
                           uint8_t *dst,
                           uint32_t dst_stride,
                           uint32_t new_width,
                           uint32_t new_height);

void pixart_yuv8_to_rgb8(const uint8_t *y_plane,
                         uint32_t y_stride,
                         const uint8_t *u_plane,
                         uint32_t u_stride,
                         const uint8_t *v_plane,
                         uint32_t v_stride,
                         uint8_t *rgba,
                         uint32_t rgba_stride,
                         uint32_t width,
                         uint32_t height,
                         YuvRange range,
                         YuvMatrix yuv_matrix,
                         YuvType yuv_type);

void pixart_yuv400_to_rgb8(const uint8_t *y_plane,
                           uint32_t y_stride,
                           uint8_t *rgba,
                           uint32_t rgba_stride,
                           uint32_t width,
                           uint32_t height,
                           YuvRange range,
                           YuvMatrix yuv_matrix);

void pixart_yuv400_with_alpha_to_rgba8(const uint8_t *y_plane,
                                       uint32_t y_stride,
                                       const uint8_t *a_plane,
                                       uint32_t a_stride,
                                       uint8_t *rgba,
                                       uint32_t rgba_stride,
                                       uint32_t width,
                                       uint32_t height,
                                       YuvRange range,
                                       YuvMatrix yuv_matrix);

void pixart_yuv400_p16_to_rgb16(const uint16_t *y_plane,
                                uint32_t y_stride,
                                uint16_t *rgba,
                                uint32_t rgba_stride,
                                uint32_t bit_depth,
                                uint32_t width,
                                uint32_t height,
                                YuvRange range,
                                YuvMatrix yuv_matrix);

void pixart_yuv400_p16_with_alpha_to_rgba16(const uint16_t *y_plane,
                                            uint32_t y_stride,
                                            const uint16_t *a_plane,
                                            uint32_t a_stride,
                                            uint16_t *rgba,
                                            uint32_t rgba_stride,
                                            uint32_t bit_depth,
                                            uint32_t width,
                                            uint32_t height,
                                            YuvRange range,
                                            YuvMatrix yuv_matrix);

void pixart_yuv8_with_alpha_to_rgba8(const uint8_t *y_plane,
                                     uint32_t y_stride,
                                     const uint8_t *u_plane,
                                     uint32_t u_stride,
                                     const uint8_t *v_plane,
                                     uint32_t v_stride,
                                     const uint8_t *a_plane,
                                     uint32_t a_stride,
                                     uint8_t *rgba,
                                     uint32_t rgba_stride,
                                     uint32_t width,
                                     uint32_t height,
                                     YuvRange range,
                                     YuvMatrix yuv_matrix,
                                     YuvType yuv_type);

void pixart_yuv16_to_rgb16(const uint16_t *y_plane,
                           uint32_t y_stride,
                           const uint16_t *u_plane,
                           uint32_t u_stride,
                           const uint16_t *v_plane,
                           uint32_t v_stride,
                           uint16_t *rgba,
                           uint32_t rgba_stride,
                           uint32_t bit_depth,
                           uint32_t width,
                           uint32_t height,
                           YuvRange range,
                           YuvMatrix yuv_matrix,
                           YuvType yuv_type);

void pixart_icgc12_r_to_rgb10(const uint16_t *y_plane,
                              uint32_t y_stride,
                              const uint16_t *u_plane,
                              uint32_t u_stride,
                              const uint16_t *v_plane,
                              uint32_t v_stride,
                              uint16_t *rgba,
                              uint32_t rgba_stride,
                              uint32_t width,
                              uint32_t height,
                              YuvRange range,
                              AvifYCgCoRType r_type,
                              YuvType yuv_type);

void pixart_icgc_r_alpha12_to_rgba10(const uint16_t *y_plane,
                                     uint32_t y_stride,
                                     const uint16_t *u_plane,
                                     uint32_t u_stride,
                                     const uint16_t *v_plane,
                                     uint32_t v_stride,
                                     const uint16_t *a_plane,
                                     uint32_t a_stride,
                                     uint16_t *rgba,
                                     uint32_t rgba_stride,
                                     uint32_t width,
                                     uint32_t height,
                                     YuvRange range,
                                     AvifYCgCoRType r_type,
                                     YuvType yuv_type);

/// Bit-depth should be 10
void pixart_icgc_r_type_to_rgb(const uint16_t *y_plane,
                               uint32_t y_stride,
                               const uint16_t *u_plane,
                               uint32_t u_stride,
                               const uint16_t *v_plane,
                               uint32_t v_stride,
                               uint8_t *rgba,
                               uint32_t rgba_stride,
                               uint32_t width,
                               uint32_t height,
                               YuvRange range,
                               AvifYCgCoRType ro_type,
                               YuvType yuv_type);

/// Bit-depth should be 10
void pixart_icgc_r_type_with_alpha_to_rgba(const uint16_t *y_plane,
                                           uint32_t y_stride,
                                           const uint16_t *u_plane,
                                           uint32_t u_stride,
                                           const uint16_t *v_plane,
                                           uint32_t v_stride,
                                           const uint16_t *a_plane,
                                           uint32_t a_stride,
                                           uint8_t *rgba,
                                           uint32_t rgba_stride,
                                           uint32_t width,
                                           uint32_t height,
                                           YuvRange range,
                                           AvifYCgCoRType ro_type,
                                           YuvType yuv_type);

void pixart_yuv16_with_alpha_to_rgba16(const uint16_t *y_plane,
                                       uint32_t y_stride,
                                       const uint16_t *u_plane,
                                       uint32_t u_stride,
                                       const uint16_t *v_plane,
                                       uint32_t v_stride,
                                       const uint16_t *a_plane,
                                       uint32_t a_stride,
                                       uint16_t *rgba,
                                       uint32_t rgba_stride,
                                       uint32_t bit_depth,
                                       uint32_t width,
                                       uint32_t height,
                                       YuvRange range,
                                       YuvMatrix yuv_matrix,
                                       YuvType yuv_type);

void pixart_yuv16_to_rgba_f16(const uint16_t *y_plane,
                              uint32_t y_stride,
                              const uint16_t *u_plane,
                              uint32_t u_stride,
                              const uint16_t *v_plane,
                              uint32_t v_stride,
                              uint16_t *rgba,
                              uint32_t rgba_stride,
                              uint32_t bit_depth,
                              uint32_t width,
                              uint32_t height,
                              YuvRange range,
                              YuvMatrix yuv_matrix,
                              YuvType yuv_type);

}  // extern "C"
