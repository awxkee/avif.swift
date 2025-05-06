/*
 * Copyright (c) Radzivon Bartoshyk. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * 1.  Redistributions of source code must retain the above copyright notice, this
 * list of conditions and the following disclaimer.
 *
 * 2.  Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * 3.  Neither the name of the copyright holder nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

use crate::support::{SliceStoreMut, transmute_const_ptr16};
use std::fmt::Debug;
use std::slice;
use yuv::{
    YuvGrayAlphaImage, YuvGrayImage, YuvPlanarImage, YuvPlanarImageWithAlpha, YuvStandardMatrix,
    convert_rgba16_to_f16, gb10_alpha_to_rgba10, gb10_to_rgb10, gb10_to_rgba_f16,
    gb12_alpha_to_rgba12, gb12_to_rgb12, gb12_to_rgba_f16, gbr_to_rgba, gbr_with_alpha_to_rgba,
    i010_alpha_to_rgba10, i010_to_rgb10, i010_to_rgba_f16, i012_alpha_to_rgba12, i012_to_rgb12,
    i012_to_rgba_f16, i210_alpha_to_rgba10, i210_to_rgb10, i210_to_rgba_f16, i212_alpha_to_rgba12,
    i212_to_rgb12, i212_to_rgba_f16, i410_alpha_to_rgba10, i410_to_rgb10, i410_to_rgba_f16,
    i412_alpha_to_rgba12, i412_to_rgb12, i412_to_rgba_f16, icgc_re_alpha010_to_rgba,
    icgc_re_alpha012_to_rgba10, icgc_re_alpha212_to_rgba10, icgc_re_alpha410_to_rgba,
    icgc_re_alpha412_to_rgba10, icgc_re010_to_rgb, icgc_re012_to_rgb10, icgc_re210_to_rgb,
    icgc_re212_to_rgb10, icgc_re410_to_rgb, icgc_re412_to_rgb10, icgc_ro_alpha010_to_rgba,
    icgc_ro_alpha012_to_rgba10, icgc_ro_alpha210_to_rgba, icgc_ro_alpha212_to_rgba10,
    icgc_ro_alpha410_to_rgba, icgc_ro_alpha412_to_rgba10, icgc_ro010_to_rgb, icgc_ro012_to_rgb10,
    icgc_ro210_to_rgb, icgc_ro212_to_rgb10, icgc_ro410_to_rgb, icgc_ro412_to_rgb10,
    icgc010_alpha_to_rgba10, icgc010_to_rgb10, icgc010_to_rgba10, icgc012_alpha_to_rgba12,
    icgc012_to_rgb12, icgc012_to_rgba12, icgc210_alpha_to_rgba10, icgc210_to_rgb10,
    icgc210_to_rgba10, icgc212_alpha_to_rgba12, icgc212_to_rgb12, icgc212_to_rgba12,
    icgc410_alpha_to_rgba10, icgc410_to_rgb10, icgc410_to_rgba10, icgc412_alpha_to_rgba12,
    icgc412_to_rgb12, icgc412_to_rgba12, y010_alpha_to_rgba10, y010_to_rgb10, y012_alpha_to_rgba12,
    y012_to_rgb12, ycgco420_alpha_to_rgba, ycgco420_to_rgb, ycgco422_alpha_to_rgba,
    ycgco422_to_rgb, ycgco444_alpha_to_rgba, ycgco444_to_rgb, yuv400_alpha_to_rgba, yuv400_to_rgb,
    yuv420_alpha_to_rgba, yuv420_to_rgb, yuv422_alpha_to_rgba, yuv422_to_rgb, yuv444_alpha_to_rgba,
    yuv444_to_rgb,
};

#[repr(C)]
#[derive(Copy, Clone, Debug, PartialEq, Ord, PartialOrd, Eq)]
pub enum YuvRange {
    Tv,
    Pc,
}

#[repr(C)]
#[derive(Copy, Clone, Debug, PartialEq, Ord, PartialOrd, Eq)]
pub enum YuvMatrix {
    Bt601,
    Bt709,
    Bt2020,
    Identity,
    YCgCo,
}

#[repr(C)]
#[derive(Copy, Clone, Debug, PartialEq, Ord, PartialOrd, Eq)]
pub enum AvifYCgCoRType {
    Ro,
    Re,
}

#[repr(C)]
#[derive(Copy, Clone, Debug, PartialEq, Ord, PartialOrd, Eq)]
pub enum YuvType {
    Yuv420,
    Yuv422,
    Yuv444,
}

#[unsafe(no_mangle)]
pub extern "C" fn pixart_yuv8_to_rgb8(
    y_plane: *const u8,
    y_stride: u32,
    u_plane: *const u8,
    u_stride: u32,
    v_plane: *const u8,
    v_stride: u32,
    rgba: *mut u8,
    rgba_stride: u32,
    width: u32,
    height: u32,
    range: YuvRange,
    yuv_matrix: YuvMatrix,
    yuv_type: YuvType,
) {
    unsafe {
        let y_slice = slice::from_raw_parts(y_plane, y_stride as usize * height as usize);
        let u_slice = if yuv_type == YuvType::Yuv420 {
            slice::from_raw_parts(u_plane, u_stride as usize * (height as usize).div_ceil(2))
        } else {
            slice::from_raw_parts(u_plane, u_stride as usize * height as usize)
        };
        let v_slice = if yuv_type == YuvType::Yuv420 {
            slice::from_raw_parts(v_plane, v_stride as usize * (height as usize).div_ceil(2))
        } else {
            slice::from_raw_parts(v_plane, v_stride as usize * height as usize)
        };
        let rgba_slice = slice::from_raw_parts_mut(rgba, height as usize * rgba_stride as usize);

        let yuv_range = match range {
            YuvRange::Tv => yuv::YuvRange::Limited,
            YuvRange::Pc => yuv::YuvRange::Full,
        };

        let planar_image = YuvPlanarImage {
            y_plane: y_slice,
            y_stride,
            u_plane: u_slice,
            u_stride,
            v_plane: v_slice,
            v_stride,
            width,
            height,
        };

        if yuv_matrix == YuvMatrix::Identity {
            assert_eq!(yuv_type, YuvType::Yuv444, "Identity exists only on 4:4:4");
            gbr_to_rgba(&planar_image, rgba_slice, rgba_stride, yuv_range).unwrap();
        } else if yuv_matrix == YuvMatrix::YCgCo {
            let callee = match yuv_type {
                YuvType::Yuv420 => ycgco420_to_rgb,
                YuvType::Yuv422 => ycgco422_to_rgb,
                YuvType::Yuv444 => ycgco444_to_rgb,
            };
            callee(&planar_image, rgba_slice, rgba_stride, yuv_range).unwrap();
        } else {
            let matrix = match yuv_matrix {
                YuvMatrix::Bt601 => YuvStandardMatrix::Bt601,
                YuvMatrix::Bt709 => YuvStandardMatrix::Bt709,
                YuvMatrix::Bt2020 => YuvStandardMatrix::Bt2020,
                YuvMatrix::Identity => unreachable!(),
                YuvMatrix::YCgCo => unreachable!(),
            };

            let callee = match yuv_type {
                YuvType::Yuv420 => yuv420_to_rgb,
                YuvType::Yuv422 => yuv422_to_rgb,
                YuvType::Yuv444 => yuv444_to_rgb,
            };

            callee(&planar_image, rgba_slice, rgba_stride, yuv_range, matrix).unwrap();
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn pixart_yuv400_to_rgb8(
    y_plane: *const u8,
    y_stride: u32,
    rgba: *mut u8,
    rgba_stride: u32,
    width: u32,
    height: u32,
    range: YuvRange,
    yuv_matrix: YuvMatrix,
) {
    unsafe {
        let y_slice = slice::from_raw_parts(y_plane, y_stride as usize * height as usize);
        let rgba_slice = slice::from_raw_parts_mut(rgba, height as usize * rgba_stride as usize);

        let yuv_range = match range {
            YuvRange::Tv => yuv::YuvRange::Limited,
            YuvRange::Pc => yuv::YuvRange::Full,
        };

        let matrix = match yuv_matrix {
            YuvMatrix::Bt601 => YuvStandardMatrix::Bt601,
            YuvMatrix::Bt709 => YuvStandardMatrix::Bt709,
            YuvMatrix::Bt2020 => YuvStandardMatrix::Bt2020,
            YuvMatrix::Identity => unreachable!("Identity exists only on 4:4:4"),
            YuvMatrix::YCgCo => unreachable!(),
        };

        let gray_image = YuvGrayImage {
            y_plane: y_slice,
            y_stride,
            width,
            height,
        };

        yuv400_to_rgb(&gray_image, rgba_slice, rgba_stride, yuv_range, matrix).unwrap();
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn pixart_yuv400_with_alpha_to_rgba8(
    y_plane: *const u8,
    y_stride: u32,
    a_plane: *const u8,
    a_stride: u32,
    rgba: *mut u8,
    rgba_stride: u32,
    width: u32,
    height: u32,
    range: YuvRange,
    yuv_matrix: YuvMatrix,
) {
    unsafe {
        let y_slice = slice::from_raw_parts(y_plane, y_stride as usize * height as usize);
        let a_plane = slice::from_raw_parts(a_plane, a_plane as usize * height as usize);
        let rgba_slice = slice::from_raw_parts_mut(rgba, height as usize * rgba_stride as usize);

        let yuv_range = match range {
            YuvRange::Tv => yuv::YuvRange::Limited,
            YuvRange::Pc => yuv::YuvRange::Full,
        };

        let gray_with_alpha = YuvGrayAlphaImage {
            y_plane: y_slice,
            y_stride,
            a_plane,
            a_stride,
            width,
            height,
        };

        let matrix = match yuv_matrix {
            YuvMatrix::Bt601 => YuvStandardMatrix::Bt601,
            YuvMatrix::Bt709 => YuvStandardMatrix::Bt709,
            YuvMatrix::Bt2020 => YuvStandardMatrix::Bt2020,
            YuvMatrix::Identity => unreachable!("Identity exists only on 4:4:4"),
            YuvMatrix::YCgCo => unreachable!(),
        };

        yuv400_alpha_to_rgba(&gray_with_alpha, rgba_slice, rgba_stride, yuv_range, matrix).unwrap();
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn pixart_yuv400_p16_to_rgb16(
    y_plane: *const u16,
    y_stride: u32,
    rgba: *mut u16,
    rgba_stride: u32,
    bit_depth: u32,
    width: u32,
    height: u32,
    range: YuvRange,
    yuv_matrix: YuvMatrix,
) {
    unsafe {
        let y_slice = transmute_const_ptr16(
            y_plane,
            y_stride as usize,
            width as usize,
            height as usize,
            1,
        );
        let rgba_slice8 =
            slice::from_raw_parts_mut(rgba as *mut u8, height as usize * rgba_stride as usize);
        let mut is_owned_rgba = false;
        let rgba_stride_u16;

        let mut working_slice = if let Ok(casted) = bytemuck::try_cast_slice_mut(rgba_slice8) {
            rgba_stride_u16 = rgba_stride / 2;
            SliceStoreMut::Borrowed(casted)
        } else {
            is_owned_rgba = true;
            rgba_stride_u16 = width * 3;
            SliceStoreMut::Owned(vec![0u16; width as usize * 3 * height as usize])
        };

        let yuv_range = match range {
            YuvRange::Tv => yuv::YuvRange::Limited,
            YuvRange::Pc => yuv::YuvRange::Full,
        };

        let matrix = match yuv_matrix {
            YuvMatrix::Bt601 => YuvStandardMatrix::Bt601,
            YuvMatrix::Bt709 => YuvStandardMatrix::Bt709,
            YuvMatrix::Bt2020 => YuvStandardMatrix::Bt2020,
            YuvMatrix::Identity => unreachable!("Identity exists only on 4:4:4"),
            YuvMatrix::YCgCo => unreachable!(),
        };

        let gray_image = YuvGrayImage {
            y_plane: y_slice.0.as_ref(),
            y_stride: y_slice.1 as u32,
            width,
            height,
        };

        let dispatch = if bit_depth == 10 {
            y010_to_rgb10
        } else {
            y012_to_rgb12
        };

        dispatch(
            &gray_image,
            working_slice.borrow_mut(),
            rgba_stride_u16,
            yuv_range,
            matrix,
        )
        .unwrap();

        let target =
            slice::from_raw_parts_mut(rgba as *mut u8, height as usize * rgba_stride as usize);
        if is_owned_rgba {
            for (dst, src) in target.chunks_exact_mut(rgba_stride as usize).zip(
                working_slice
                    .borrow()
                    .chunks_exact(rgba_stride_u16 as usize),
            ) {
                for (dst, src) in dst.chunks_exact_mut(2).zip(src.iter()) {
                    let bytes = src.to_ne_bytes();
                    dst[0] = bytes[0];
                    dst[1] = bytes[1];
                }
            }
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn pixart_yuv400_p16_with_alpha_to_rgba16(
    y_plane: *const u16,
    y_stride: u32,
    a_plane: *const u16,
    a_stride: u32,
    rgba: *mut u16,
    rgba_stride: u32,
    bit_depth: u32,
    width: u32,
    height: u32,
    range: YuvRange,
    yuv_matrix: YuvMatrix,
) {
    unsafe {
        let y_slice = transmute_const_ptr16(
            y_plane,
            y_stride as usize,
            width as usize,
            height as usize,
            1,
        );

        let yuv_range = match range {
            YuvRange::Tv => yuv::YuvRange::Limited,
            YuvRange::Pc => yuv::YuvRange::Full,
        };

        let matrix = match yuv_matrix {
            YuvMatrix::Bt601 => YuvStandardMatrix::Bt601,
            YuvMatrix::Bt709 => YuvStandardMatrix::Bt709,
            YuvMatrix::Bt2020 => YuvStandardMatrix::Bt2020,
            YuvMatrix::Identity => unreachable!("Identity exists only on 4:4:4"),
            YuvMatrix::YCgCo => unreachable!(),
        };

        let a_orig = transmute_const_ptr16(
            a_plane,
            a_stride as usize,
            width as usize,
            height as usize,
            1,
        );

        let rgba_slice8 =
            slice::from_raw_parts_mut(rgba as *mut u8, height as usize * rgba_stride as usize);
        let mut is_owned_rgba = false;
        let rgba_stride_u16;

        let mut working_slice = if let Ok(casted) = bytemuck::try_cast_slice_mut(rgba_slice8) {
            rgba_stride_u16 = rgba_stride / 2;
            SliceStoreMut::Borrowed(casted)
        } else {
            is_owned_rgba = true;
            rgba_stride_u16 = width * 4;
            SliceStoreMut::Owned(vec![0u16; width as usize * 4 * height as usize])
        };

        let gray_alpha = YuvGrayAlphaImage {
            y_plane: y_slice.0.as_ref(),
            y_stride: y_slice.1 as u32,
            a_plane: a_orig.0.as_ref(),
            a_stride: a_orig.1 as u32,
            width,
            height,
        };

        let dispatch = if bit_depth == 10 {
            y010_alpha_to_rgba10
        } else {
            y012_alpha_to_rgba12
        };

        dispatch(
            &gray_alpha,
            working_slice.borrow_mut(),
            rgba_stride_u16,
            yuv_range,
            matrix,
        )
        .unwrap();

        let target =
            slice::from_raw_parts_mut(rgba as *mut u8, height as usize * rgba_stride as usize);
        if is_owned_rgba {
            for (dst, src) in target.chunks_exact_mut(rgba_stride as usize).zip(
                working_slice
                    .borrow()
                    .chunks_exact(rgba_stride_u16 as usize),
            ) {
                for (dst, src) in dst.chunks_exact_mut(2).zip(src.iter()) {
                    let bytes = src.to_ne_bytes();
                    dst[0] = bytes[0];
                    dst[1] = bytes[1];
                }
            }
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn pixart_yuv8_with_alpha_to_rgba8(
    y_plane: *const u8,
    y_stride: u32,
    u_plane: *const u8,
    u_stride: u32,
    v_plane: *const u8,
    v_stride: u32,
    a_plane: *const u8,
    a_stride: u32,
    rgba: *mut u8,
    rgba_stride: u32,
    width: u32,
    height: u32,
    range: YuvRange,
    yuv_matrix: YuvMatrix,
    yuv_type: YuvType,
) {
    unsafe {
        let y_slice = slice::from_raw_parts(y_plane, y_stride as usize * height as usize);
        let a_slice = slice::from_raw_parts(a_plane, a_stride as usize * height as usize);
        let u_slice = if yuv_type == YuvType::Yuv420 {
            slice::from_raw_parts(u_plane, u_stride as usize * height.div_ceil(2) as usize)
        } else {
            slice::from_raw_parts(u_plane, u_stride as usize * height as usize)
        };
        let v_slice = if yuv_type == YuvType::Yuv420 {
            slice::from_raw_parts(v_plane, v_stride as usize * height.div_ceil(2) as usize)
        } else {
            slice::from_raw_parts(v_plane, v_stride as usize * height as usize)
        };
        let rgba_slice = slice::from_raw_parts_mut(rgba, height as usize * rgba_stride as usize);

        let yuv_range = match range {
            YuvRange::Tv => yuv::YuvRange::Limited,
            YuvRange::Pc => yuv::YuvRange::Full,
        };

        let planar_with_alpha = YuvPlanarImageWithAlpha {
            y_plane: y_slice,
            y_stride,
            u_plane: u_slice,
            u_stride,
            v_plane: v_slice,
            v_stride,
            a_plane: a_slice,
            a_stride,
            width,
            height,
        };

        if yuv_matrix == YuvMatrix::Identity {
            assert_eq!(yuv_type, YuvType::Yuv444, "Identity exists only on 4:4:4");
            gbr_with_alpha_to_rgba(&planar_with_alpha, rgba_slice, rgba_stride, yuv_range).unwrap();
        } else if yuv_matrix == YuvMatrix::YCgCo {
            let callee = match yuv_type {
                YuvType::Yuv420 => ycgco420_alpha_to_rgba,
                YuvType::Yuv422 => ycgco422_alpha_to_rgba,
                YuvType::Yuv444 => ycgco444_alpha_to_rgba,
            };
            callee(&planar_with_alpha, rgba_slice, rgba_stride, yuv_range).unwrap();
        } else {
            let matrix = match yuv_matrix {
                YuvMatrix::Bt601 => YuvStandardMatrix::Bt601,
                YuvMatrix::Bt709 => YuvStandardMatrix::Bt709,
                YuvMatrix::Bt2020 => YuvStandardMatrix::Bt2020,
                YuvMatrix::Identity => unreachable!("Should be handled in another place"),
                YuvMatrix::YCgCo => unreachable!(),
            };

            let callee = match yuv_type {
                YuvType::Yuv420 => yuv420_alpha_to_rgba,
                YuvType::Yuv422 => yuv422_alpha_to_rgba,
                YuvType::Yuv444 => yuv444_alpha_to_rgba,
            };

            callee(
                &planar_with_alpha,
                rgba_slice,
                rgba_stride,
                yuv_range,
                matrix,
                false,
            )
            .unwrap();
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn pixart_yuv16_to_rgb16(
    y_plane: *const u16,
    y_stride: u32,
    u_plane: *const u16,
    u_stride: u32,
    v_plane: *const u16,
    v_stride: u32,
    rgba: *mut u16,
    rgba_stride: u32,
    bit_depth: u32,
    width: u32,
    height: u32,
    range: YuvRange,
    yuv_matrix: YuvMatrix,
    yuv_type: YuvType,
) {
    unsafe {
        let y_slice = transmute_const_ptr16(
            y_plane,
            y_stride as usize,
            width as usize,
            height as usize,
            1,
        );
        let chroma_height = if yuv_type == YuvType::Yuv420 {
            height.div_ceil(2) as usize
        } else {
            height as usize
        };
        let chroma_width = if yuv_type == YuvType::Yuv420 {
            width.div_ceil(2) as usize
        } else {
            width as usize
        };
        let u_slice =
            transmute_const_ptr16(u_plane, u_stride as usize, chroma_width, chroma_height, 1);
        let v_slice =
            transmute_const_ptr16(v_plane, v_stride as usize, chroma_width, chroma_height, 1);

        let rgba_slice8 =
            slice::from_raw_parts_mut(rgba as *mut u8, height as usize * rgba_stride as usize);
        let mut is_owned_rgba = false;
        let rgba_stride_u16;

        let mut working_slice = if let Ok(casted) = bytemuck::try_cast_slice_mut(rgba_slice8) {
            rgba_stride_u16 = rgba_stride / 2;
            SliceStoreMut::Borrowed(casted)
        } else {
            is_owned_rgba = true;
            rgba_stride_u16 = width * 3;
            SliceStoreMut::Owned(vec![0u16; width as usize * 3 * height as usize])
        };

        let yuv_range = match range {
            YuvRange::Tv => yuv::YuvRange::Limited,
            YuvRange::Pc => yuv::YuvRange::Full,
        };

        let planar_image_with_alpha = YuvPlanarImage {
            y_plane: y_slice.0.as_ref(),
            y_stride: y_slice.1 as u32,
            u_plane: u_slice.0.as_ref(),
            u_stride: u_slice.1 as u32,
            v_plane: v_slice.0.as_ref(),
            v_stride: v_slice.1 as u32,
            width,
            height,
        };

        if yuv_matrix == YuvMatrix::Identity {
            assert_eq!(yuv_type, YuvType::Yuv444, "Identity exists only on 4:4:4");
            let dispatch = if bit_depth == 10 {
                gb10_to_rgb10
            } else {
                gb12_to_rgb12
            };
            dispatch(
                &planar_image_with_alpha,
                working_slice.borrow_mut(),
                rgba_stride_u16,
                yuv_range,
            )
            .unwrap();
        } else if yuv_matrix == YuvMatrix::YCgCo {
            let callee = match yuv_type {
                YuvType::Yuv420 => {
                    if bit_depth == 10 {
                        icgc010_to_rgb10
                    } else {
                        icgc012_to_rgb12
                    }
                }
                YuvType::Yuv422 => {
                    if bit_depth == 10 {
                        icgc210_to_rgb10
                    } else {
                        icgc212_to_rgb12
                    }
                }
                YuvType::Yuv444 => {
                    if bit_depth == 10 {
                        icgc410_to_rgb10
                    } else {
                        icgc412_to_rgb12
                    }
                }
            };

            callee(
                &planar_image_with_alpha,
                working_slice.borrow_mut(),
                rgba_stride_u16,
                yuv_range,
            )
            .unwrap();
        } else {
            let matrix = match yuv_matrix {
                YuvMatrix::Bt601 => YuvStandardMatrix::Bt601,
                YuvMatrix::Bt709 => YuvStandardMatrix::Bt709,
                YuvMatrix::Bt2020 => YuvStandardMatrix::Bt2020,
                YuvMatrix::Identity => unreachable!("Should be handled in another place"),
                YuvMatrix::YCgCo => unreachable!(),
            };

            let callee = match yuv_type {
                YuvType::Yuv420 => {
                    if bit_depth == 10 {
                        i010_to_rgb10
                    } else {
                        i012_to_rgb12
                    }
                }
                YuvType::Yuv422 => {
                    if bit_depth == 10 {
                        i210_to_rgb10
                    } else {
                        i212_to_rgb12
                    }
                }
                YuvType::Yuv444 => {
                    if bit_depth == 10 {
                        i410_to_rgb10
                    } else {
                        i412_to_rgb12
                    }
                }
            };

            callee(
                &planar_image_with_alpha,
                working_slice.borrow_mut(),
                rgba_stride_u16,
                yuv_range,
                matrix,
            )
            .unwrap();
        }

        let target =
            slice::from_raw_parts_mut(rgba as *mut u8, height as usize * rgba_stride as usize);
        if is_owned_rgba {
            for (dst, src) in target.chunks_exact_mut(rgba_stride as usize).zip(
                working_slice
                    .borrow()
                    .chunks_exact(rgba_stride_u16 as usize),
            ) {
                for (dst, src) in dst.chunks_exact_mut(2).zip(src.iter()) {
                    let bytes = src.to_ne_bytes();
                    dst[0] = bytes[0];
                    dst[1] = bytes[1];
                }
            }
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn pixart_icgc12_r_to_rgb10(
    y_plane: *const u16,
    y_stride: u32,
    u_plane: *const u16,
    u_stride: u32,
    v_plane: *const u16,
    v_stride: u32,
    rgba: *mut u16,
    rgba_stride: u32,
    width: u32,
    height: u32,
    range: YuvRange,
    r_type: AvifYCgCoRType,
    yuv_type: YuvType,
) {
    unsafe {
        let y_slice = transmute_const_ptr16(
            y_plane,
            y_stride as usize,
            width as usize,
            height as usize,
            1,
        );
        let chroma_height = if yuv_type == YuvType::Yuv420 {
            height.div_ceil(2) as usize
        } else {
            height as usize
        };
        let chroma_width = if yuv_type == YuvType::Yuv420 {
            width.div_ceil(2) as usize
        } else {
            width as usize
        };
        let u_slice =
            transmute_const_ptr16(u_plane, u_stride as usize, chroma_width, chroma_height, 1);
        let v_slice =
            transmute_const_ptr16(v_plane, v_stride as usize, chroma_width, chroma_height, 1);

        let rgba_slice8 =
            slice::from_raw_parts_mut(rgba as *mut u8, height as usize * rgba_stride as usize);
        let mut is_owned_rgba = false;
        let rgba_stride_u16;

        let mut working_slice = if let Ok(casted) = bytemuck::try_cast_slice_mut(rgba_slice8) {
            rgba_stride_u16 = rgba_stride / 2;
            SliceStoreMut::Borrowed(casted)
        } else {
            is_owned_rgba = true;
            rgba_stride_u16 = width * 3;
            SliceStoreMut::Owned(vec![0u16; width as usize * 3 * height as usize])
        };

        let yuv_range = match range {
            YuvRange::Tv => yuv::YuvRange::Limited,
            YuvRange::Pc => yuv::YuvRange::Full,
        };

        let planar_image_with_alpha = YuvPlanarImage {
            y_plane: y_slice.0.as_ref(),
            y_stride: y_slice.1 as u32,
            u_plane: u_slice.0.as_ref(),
            u_stride: u_slice.1 as u32,
            v_plane: v_slice.0.as_ref(),
            v_stride: v_slice.1 as u32,
            width,
            height,
        };

        let callee = match yuv_type {
            YuvType::Yuv420 => match r_type {
                AvifYCgCoRType::Ro => icgc_ro012_to_rgb10,
                AvifYCgCoRType::Re => icgc_re012_to_rgb10,
            },
            YuvType::Yuv422 => match r_type {
                AvifYCgCoRType::Ro => icgc_ro212_to_rgb10,
                AvifYCgCoRType::Re => icgc_re212_to_rgb10,
            },
            YuvType::Yuv444 => match r_type {
                AvifYCgCoRType::Ro => icgc_ro412_to_rgb10,
                AvifYCgCoRType::Re => icgc_re412_to_rgb10,
            },
        };

        callee(
            &planar_image_with_alpha,
            working_slice.borrow_mut(),
            rgba_stride_u16,
            yuv_range,
        )
        .unwrap();

        let target =
            slice::from_raw_parts_mut(rgba as *mut u8, height as usize * rgba_stride as usize);
        if is_owned_rgba {
            for (dst, src) in target.chunks_exact_mut(rgba_stride as usize).zip(
                working_slice
                    .borrow()
                    .chunks_exact(rgba_stride_u16 as usize),
            ) {
                for (dst, src) in dst.chunks_exact_mut(2).zip(src.iter()) {
                    let bytes = src.to_ne_bytes();
                    dst[0] = bytes[0];
                    dst[1] = bytes[1];
                }
            }
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn pixart_icgc_r_alpha12_to_rgba10(
    y_plane: *const u16,
    y_stride: u32,
    u_plane: *const u16,
    u_stride: u32,
    v_plane: *const u16,
    v_stride: u32,
    a_plane: *const u16,
    a_stride: u32,
    rgba: *mut u16,
    rgba_stride: u32,
    width: u32,
    height: u32,
    range: YuvRange,
    r_type: AvifYCgCoRType,
    yuv_type: YuvType,
) {
    unsafe {
        let y_slice = transmute_const_ptr16(
            y_plane,
            y_stride as usize,
            width as usize,
            height as usize,
            1,
        );
        let chroma_height = if yuv_type == YuvType::Yuv420 {
            height.div_ceil(2) as usize
        } else {
            height as usize
        };
        let chroma_width = if yuv_type == YuvType::Yuv420 {
            width.div_ceil(2) as usize
        } else {
            width as usize
        };
        let u_slice =
            transmute_const_ptr16(u_plane, u_stride as usize, chroma_width, chroma_height, 1);
        let v_slice =
            transmute_const_ptr16(v_plane, v_stride as usize, chroma_width, chroma_height, 1);

        let a_slice = transmute_const_ptr16(
            a_plane,
            a_stride as usize,
            width as usize,
            height as usize,
            1,
        );

        let rgba_slice8 =
            slice::from_raw_parts_mut(rgba as *mut u8, height as usize * rgba_stride as usize);
        let mut is_owned_rgba = false;
        let rgba_stride_u16;

        let mut working_slice = if let Ok(casted) = bytemuck::try_cast_slice_mut(rgba_slice8) {
            rgba_stride_u16 = rgba_stride / 2;
            SliceStoreMut::Borrowed(casted)
        } else {
            is_owned_rgba = true;
            rgba_stride_u16 = width * 4;
            SliceStoreMut::Owned(vec![0u16; width as usize * 4 * height as usize])
        };

        let yuv_range = match range {
            YuvRange::Tv => yuv::YuvRange::Limited,
            YuvRange::Pc => yuv::YuvRange::Full,
        };

        let planar_image_with_alpha = YuvPlanarImageWithAlpha {
            y_plane: y_slice.0.as_ref(),
            y_stride: y_slice.1 as u32,
            u_plane: u_slice.0.as_ref(),
            u_stride: u_slice.1 as u32,
            v_plane: v_slice.0.as_ref(),
            v_stride: v_slice.1 as u32,
            a_plane: a_slice.0.as_ref(),
            a_stride: a_slice.1 as u32,
            width,
            height,
        };

        let callee = match yuv_type {
            YuvType::Yuv420 => match r_type {
                AvifYCgCoRType::Ro => icgc_ro_alpha012_to_rgba10,
                AvifYCgCoRType::Re => icgc_re_alpha012_to_rgba10,
            },
            YuvType::Yuv422 => match r_type {
                AvifYCgCoRType::Ro => icgc_ro_alpha212_to_rgba10,
                AvifYCgCoRType::Re => icgc_re_alpha212_to_rgba10,
            },
            YuvType::Yuv444 => match r_type {
                AvifYCgCoRType::Ro => icgc_ro_alpha412_to_rgba10,
                AvifYCgCoRType::Re => icgc_re_alpha412_to_rgba10,
            },
        };

        callee(
            &planar_image_with_alpha,
            working_slice.borrow_mut(),
            rgba_stride_u16,
            yuv_range,
        )
        .unwrap();

        let target =
            slice::from_raw_parts_mut(rgba as *mut u8, height as usize * rgba_stride as usize);
        if is_owned_rgba {
            for (dst, src) in target.chunks_exact_mut(rgba_stride as usize).zip(
                working_slice
                    .borrow()
                    .chunks_exact(rgba_stride_u16 as usize),
            ) {
                for (dst, src) in dst.chunks_exact_mut(2).zip(src.iter()) {
                    let bytes = src.to_ne_bytes();
                    dst[0] = bytes[0];
                    dst[1] = bytes[1];
                }
            }
        }
    }
}

/// Bit-depth should be 10
#[unsafe(no_mangle)]
pub extern "C" fn pixart_icgc_r_type_to_rgb(
    y_plane: *const u16,
    y_stride: u32,
    u_plane: *const u16,
    u_stride: u32,
    v_plane: *const u16,
    v_stride: u32,
    rgba: *mut u8,
    rgba_stride: u32,
    width: u32,
    height: u32,
    range: YuvRange,
    ro_type: AvifYCgCoRType,
    yuv_type: YuvType,
) {
    unsafe {
        let y_slice = transmute_const_ptr16(
            y_plane,
            y_stride as usize,
            width as usize,
            height as usize,
            1,
        );
        let chroma_height = if yuv_type == YuvType::Yuv420 {
            height.div_ceil(2) as usize
        } else {
            height as usize
        };
        let chroma_width = if yuv_type == YuvType::Yuv420 {
            width.div_ceil(2) as usize
        } else {
            width as usize
        };
        let u_slice =
            transmute_const_ptr16(u_plane, u_stride as usize, chroma_width, chroma_height, 1);
        let v_slice =
            transmute_const_ptr16(v_plane, v_stride as usize, chroma_width, chroma_height, 1);

        let rgba_slice8 = slice::from_raw_parts_mut(rgba, height as usize * rgba_stride as usize);

        let yuv_range = match range {
            YuvRange::Tv => yuv::YuvRange::Limited,
            YuvRange::Pc => yuv::YuvRange::Full,
        };

        let planar_image_with_alpha = YuvPlanarImage {
            y_plane: y_slice.0.as_ref(),
            y_stride: y_slice.1 as u32,
            u_plane: u_slice.0.as_ref(),
            u_stride: u_slice.1 as u32,
            v_plane: v_slice.0.as_ref(),
            v_stride: v_slice.1 as u32,
            width,
            height,
        };

        let callee = match yuv_type {
            YuvType::Yuv420 => match ro_type {
                AvifYCgCoRType::Ro => icgc_ro010_to_rgb,
                AvifYCgCoRType::Re => icgc_re010_to_rgb,
            },
            YuvType::Yuv422 => match ro_type {
                AvifYCgCoRType::Ro => icgc_ro210_to_rgb,
                AvifYCgCoRType::Re => icgc_re210_to_rgb,
            },
            YuvType::Yuv444 => match ro_type {
                AvifYCgCoRType::Ro => icgc_ro410_to_rgb,
                AvifYCgCoRType::Re => icgc_re410_to_rgb,
            },
        };

        callee(
            &planar_image_with_alpha,
            rgba_slice8,
            rgba_stride,
            yuv_range,
        )
        .unwrap();
    }
}

/// Bit-depth should be 10
#[unsafe(no_mangle)]
pub extern "C" fn pixart_icgc_r_type_with_alpha_to_rgba(
    y_plane: *const u16,
    y_stride: u32,
    u_plane: *const u16,
    u_stride: u32,
    v_plane: *const u16,
    v_stride: u32,
    a_plane: *const u16,
    a_stride: u32,
    rgba: *mut u8,
    rgba_stride: u32,
    width: u32,
    height: u32,
    range: YuvRange,
    ro_type: AvifYCgCoRType,
    yuv_type: YuvType,
) {
    unsafe {
        let y_slice = transmute_const_ptr16(
            y_plane,
            y_stride as usize,
            width as usize,
            height as usize,
            1,
        );
        let chroma_height = if yuv_type == YuvType::Yuv420 {
            height.div_ceil(2) as usize
        } else {
            height as usize
        };
        let chroma_width = if yuv_type == YuvType::Yuv420 {
            width.div_ceil(2) as usize
        } else {
            width as usize
        };
        let u_slice =
            transmute_const_ptr16(u_plane, u_stride as usize, chroma_width, chroma_height, 1);
        let v_slice =
            transmute_const_ptr16(v_plane, v_stride as usize, chroma_width, chroma_height, 1);

        let a_slice = transmute_const_ptr16(
            a_plane,
            a_stride as usize,
            width as usize,
            height as usize,
            1,
        );

        let rgba_slice8 = slice::from_raw_parts_mut(rgba, height as usize * rgba_stride as usize);

        let yuv_range = match range {
            YuvRange::Tv => yuv::YuvRange::Limited,
            YuvRange::Pc => yuv::YuvRange::Full,
        };

        let planar_image_with_alpha = YuvPlanarImageWithAlpha {
            y_plane: y_slice.0.as_ref(),
            y_stride: y_slice.1 as u32,
            u_plane: u_slice.0.as_ref(),
            u_stride: u_slice.1 as u32,
            v_plane: v_slice.0.as_ref(),
            v_stride: v_slice.1 as u32,
            a_plane: a_slice.0.as_ref(),
            a_stride: a_slice.1 as u32,
            width,
            height,
        };

        let callee = match yuv_type {
            YuvType::Yuv420 => match ro_type {
                AvifYCgCoRType::Ro => icgc_ro_alpha010_to_rgba,
                AvifYCgCoRType::Re => icgc_re_alpha010_to_rgba,
            },
            YuvType::Yuv422 => match ro_type {
                AvifYCgCoRType::Ro => icgc_ro_alpha210_to_rgba,
                AvifYCgCoRType::Re => icgc_re_alpha010_to_rgba,
            },
            YuvType::Yuv444 => match ro_type {
                AvifYCgCoRType::Ro => icgc_ro_alpha410_to_rgba,
                AvifYCgCoRType::Re => icgc_re_alpha410_to_rgba,
            },
        };

        callee(
            &planar_image_with_alpha,
            rgba_slice8,
            rgba_stride,
            yuv_range,
        )
        .unwrap();

        let a_slice = transmute_const_ptr16(
            a_plane,
            a_stride as usize,
            width as usize,
            height as usize,
            1,
        );

        for (rgba_row, a_row) in rgba_slice8
            .chunks_exact_mut(rgba_stride as usize)
            .zip(a_slice.0.as_ref().chunks_exact(a_slice.1))
        {
            for (rgb, &alpha) in rgba_row.chunks_exact_mut(4).zip(a_row.iter()) {
                let a = ((alpha + 1) >> 2).min(255) as u8;
                rgb[3] = a;
            }
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn pixart_yuv16_with_alpha_to_rgba16(
    y_plane: *const u16,
    y_stride: u32,
    u_plane: *const u16,
    u_stride: u32,
    v_plane: *const u16,
    v_stride: u32,
    a_plane: *const u16,
    a_stride: u32,
    rgba: *mut u16,
    rgba_stride: u32,
    bit_depth: u32,
    width: u32,
    height: u32,
    range: YuvRange,
    yuv_matrix: YuvMatrix,
    yuv_type: YuvType,
) {
    unsafe {
        let y_slice = transmute_const_ptr16(
            y_plane,
            y_stride as usize,
            width as usize,
            height as usize,
            1,
        );
        let a_orig = transmute_const_ptr16(
            a_plane,
            a_stride as usize,
            width as usize,
            height as usize,
            1,
        );
        let chroma_height = if yuv_type == YuvType::Yuv420 {
            height.div_ceil(2) as usize
        } else {
            height as usize
        };
        let chroma_width = if yuv_type == YuvType::Yuv420 {
            width.div_ceil(2) as usize
        } else {
            width as usize
        };
        let u_slice =
            transmute_const_ptr16(u_plane, u_stride as usize, chroma_width, chroma_height, 1);
        let v_slice =
            transmute_const_ptr16(v_plane, v_stride as usize, chroma_width, chroma_height, 1);

        let rgba_slice8 =
            slice::from_raw_parts_mut(rgba as *mut u8, height as usize * rgba_stride as usize);
        let mut is_owned_rgba = false;
        let rgba_stride_u16;

        let mut working_slice = if let Ok(casted) = bytemuck::try_cast_slice_mut(rgba_slice8) {
            rgba_stride_u16 = rgba_stride / 2;
            SliceStoreMut::Borrowed(casted)
        } else {
            is_owned_rgba = true;
            rgba_stride_u16 = width * 4;
            SliceStoreMut::Owned(vec![0u16; width as usize * 4 * height as usize])
        };

        let yuv_range = match range {
            YuvRange::Tv => yuv::YuvRange::Limited,
            YuvRange::Pc => yuv::YuvRange::Full,
        };

        let planar_image_with_alpha = YuvPlanarImageWithAlpha {
            y_plane: y_slice.0.as_ref(),
            y_stride: y_slice.1 as u32,
            u_plane: u_slice.0.as_ref(),
            u_stride: u_slice.1 as u32,
            v_plane: v_slice.0.as_ref(),
            v_stride: v_slice.1 as u32,
            a_plane: a_orig.0.as_ref(),
            a_stride: a_orig.1 as u32,
            width,
            height,
        };

        if yuv_matrix == YuvMatrix::Identity {
            assert_eq!(
                yuv_type,
                YuvType::Yuv444,
                "Identity exists only in 4:4:4 layout"
            );
            let dispatch = if bit_depth == 10 {
                gb10_alpha_to_rgba10
            } else {
                gb12_alpha_to_rgba12
            };
            dispatch(
                &planar_image_with_alpha,
                working_slice.borrow_mut(),
                rgba_stride_u16,
                yuv_range,
            )
            .unwrap();
        } else if yuv_matrix == YuvMatrix::YCgCo {
            let callee = match yuv_type {
                YuvType::Yuv420 => {
                    if bit_depth == 10 {
                        icgc010_alpha_to_rgba10
                    } else {
                        icgc012_alpha_to_rgba12
                    }
                }
                YuvType::Yuv422 => {
                    if bit_depth == 10 {
                        icgc210_alpha_to_rgba10
                    } else {
                        icgc212_alpha_to_rgba12
                    }
                }
                YuvType::Yuv444 => {
                    if bit_depth == 10 {
                        icgc410_alpha_to_rgba10
                    } else {
                        icgc412_alpha_to_rgba12
                    }
                }
            };

            callee(
                &planar_image_with_alpha,
                working_slice.borrow_mut(),
                rgba_stride_u16,
                yuv_range,
            )
            .unwrap();
        } else {
            let matrix = match yuv_matrix {
                YuvMatrix::Bt601 => YuvStandardMatrix::Bt601,
                YuvMatrix::Bt709 => YuvStandardMatrix::Bt709,
                YuvMatrix::Bt2020 => YuvStandardMatrix::Bt2020,
                YuvMatrix::Identity => unreachable!("Should be handled in another place"),
                YuvMatrix::YCgCo => unreachable!("Should be handled in another place"),
            };

            let callee = match yuv_type {
                YuvType::Yuv420 => {
                    if bit_depth == 10 {
                        i010_alpha_to_rgba10
                    } else {
                        i012_alpha_to_rgba12
                    }
                }
                YuvType::Yuv422 => {
                    if bit_depth == 10 {
                        i210_alpha_to_rgba10
                    } else {
                        i212_alpha_to_rgba12
                    }
                }
                YuvType::Yuv444 => {
                    if bit_depth == 10 {
                        i410_alpha_to_rgba10
                    } else {
                        i412_alpha_to_rgba12
                    }
                }
            };

            callee(
                &planar_image_with_alpha,
                working_slice.borrow_mut(),
                rgba_stride_u16,
                yuv_range,
                matrix,
            )
            .unwrap();
        }

        let target =
            slice::from_raw_parts_mut(rgba as *mut u8, height as usize * rgba_stride as usize);
        if is_owned_rgba {
            for (dst, src) in target.chunks_exact_mut(rgba_stride as usize).zip(
                working_slice
                    .borrow()
                    .chunks_exact(rgba_stride_u16 as usize),
            ) {
                for (dst, src) in dst.chunks_exact_mut(2).zip(src.iter()) {
                    let bytes = src.to_ne_bytes();
                    dst[0] = bytes[0];
                    dst[1] = bytes[1];
                }
            }
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn pixart_yuv16_to_rgba_f16(
    y_plane: *const u16,
    y_stride: u32,
    u_plane: *const u16,
    u_stride: u32,
    v_plane: *const u16,
    v_stride: u32,
    rgba: *mut u16,
    rgba_stride: u32,
    bit_depth: u32,
    width: u32,
    height: u32,
    range: YuvRange,
    yuv_matrix: YuvMatrix,
    yuv_type: YuvType,
) {
    unsafe {
        let y_slice = transmute_const_ptr16(
            y_plane,
            y_stride as usize,
            width as usize,
            height as usize,
            1,
        );
        let chroma_height = if yuv_type == YuvType::Yuv420 {
            height.div_ceil(2) as usize
        } else {
            height as usize
        };
        let chroma_width = if yuv_type == YuvType::Yuv420 {
            width.div_ceil(2) as usize
        } else {
            width as usize
        };
        let u_slice =
            transmute_const_ptr16(u_plane, u_stride as usize, chroma_width, chroma_height, 1);
        let v_slice =
            transmute_const_ptr16(v_plane, v_stride as usize, chroma_width, chroma_height, 1);

        let rgba_slice8 =
            slice::from_raw_parts_mut(rgba as *mut u8, height as usize * rgba_stride as usize);

        let mut is_owned_rgba = false;
        let rgba_stride_u16;

        let mut working_slice = if let Ok(casted) = bytemuck::try_cast_slice_mut(rgba_slice8) {
            rgba_stride_u16 = rgba_stride / 2;
            SliceStoreMut::Borrowed(casted)
        } else {
            is_owned_rgba = true;
            rgba_stride_u16 = width * 4;
            SliceStoreMut::Owned(vec![0_f16; width as usize * 4 * height as usize])
        };

        let yuv_range = match range {
            YuvRange::Tv => yuv::YuvRange::Limited,
            YuvRange::Pc => yuv::YuvRange::Full,
        };

        let planar_image_with_alpha = YuvPlanarImage {
            y_plane: y_slice.0.as_ref(),
            y_stride: y_slice.1 as u32,
            u_plane: u_slice.0.as_ref(),
            u_stride: u_slice.1 as u32,
            v_plane: v_slice.0.as_ref(),
            v_stride: v_slice.1 as u32,
            width,
            height,
        };

        if yuv_matrix == YuvMatrix::Identity {
            assert_eq!(yuv_type, YuvType::Yuv444, "Identity exists only on 4:4:4");
            let dispatch = if bit_depth == 10 {
                gb10_to_rgba_f16
            } else {
                gb12_to_rgba_f16
            };
            dispatch(
                &planar_image_with_alpha,
                bytemuck::cast_slice_mut(working_slice.borrow_mut()),
                rgba_stride_u16,
                yuv_range,
            )
            .unwrap();
        } else if yuv_matrix == YuvMatrix::YCgCo {
            let mut working_target = vec![0u16; width as usize * height as usize * 4];
            let callee = match yuv_type {
                YuvType::Yuv420 => {
                    if bit_depth == 10 {
                        icgc010_to_rgba10
                    } else {
                        icgc012_to_rgba12
                    }
                }
                YuvType::Yuv422 => {
                    if bit_depth == 10 {
                        icgc210_to_rgba10
                    } else {
                        icgc212_to_rgba12
                    }
                }
                YuvType::Yuv444 => {
                    if bit_depth == 10 {
                        icgc410_to_rgba10
                    } else {
                        icgc412_to_rgba12
                    }
                }
            };

            callee(
                &planar_image_with_alpha,
                &mut working_target,
                rgba_stride_u16,
                yuv_range,
            )
            .unwrap();
            convert_rgba16_to_f16(
                &working_target,
                width as usize * 4,
                working_slice.borrow_mut(),
                rgba_stride_u16 as usize,
                bit_depth as usize,
                width as usize,
                height as usize,
            )
            .unwrap();
        } else {
            let matrix = match yuv_matrix {
                YuvMatrix::Bt601 => YuvStandardMatrix::Bt601,
                YuvMatrix::Bt709 => YuvStandardMatrix::Bt709,
                YuvMatrix::Bt2020 => YuvStandardMatrix::Bt2020,
                YuvMatrix::Identity => unreachable!("Should be handled in another place"),
                YuvMatrix::YCgCo => unreachable!(),
            };

            let callee = match yuv_type {
                YuvType::Yuv420 => {
                    if bit_depth == 10 {
                        i010_to_rgba_f16
                    } else {
                        i012_to_rgba_f16
                    }
                }
                YuvType::Yuv422 => {
                    if bit_depth == 10 {
                        i210_to_rgba_f16
                    } else {
                        i212_to_rgba_f16
                    }
                }
                YuvType::Yuv444 => {
                    if bit_depth == 10 {
                        i410_to_rgba_f16
                    } else {
                        i412_to_rgba_f16
                    }
                }
            };

            callee(
                &planar_image_with_alpha,
                working_slice.borrow_mut(),
                rgba_stride_u16,
                yuv_range,
                matrix,
            )
            .unwrap();
        }

        if is_owned_rgba {
            let target =
                slice::from_raw_parts_mut(rgba as *mut u8, height as usize * rgba_stride as usize);
            for (dst, src) in target.chunks_exact_mut(rgba_stride as usize).zip(
                working_slice
                    .borrow()
                    .chunks_exact(rgba_stride_u16 as usize),
            ) {
                for (dst, src) in dst.chunks_exact_mut(2).zip(src.iter()) {
                    let bytes = src.to_bits().to_ne_bytes();
                    dst[0] = bytes[0];
                    dst[1] = bytes[1];
                }
            }
        }
    }
}
