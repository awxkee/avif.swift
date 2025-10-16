/*
 * Copyright (c) Radzivon Bartoshyk 2025/5. All rights reserved.
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
use crate::AvifYCgCoRType;
use crate::yuv_to_rgb::{YuvMatrix, YuvRange, YuvType};
use std::slice;
use yuv::{
    BufferStoreMut, YuvConversionMode, YuvGrayImageMut, YuvPlanarImageMut, YuvStandardMatrix,
    rgba_to_gbr, rgba_to_icgc_re010, rgba_to_icgc_re210, rgba_to_icgc_re410, rgba_to_icgc_ro010,
    rgba_to_icgc_ro210, rgba_to_icgc_ro410, rgba_to_ycgco420, rgba_to_ycgco422, rgba_to_ycgco444,
    rgba_to_yuv400, rgba_to_yuv420, rgba_to_yuv422, rgba_to_yuv444,
};

#[unsafe(no_mangle)]
pub extern "C" fn pixart_rgba8_to_yuv8(
    y_plane: *mut u8,
    y_stride: u32,
    u_plane: *mut u8,
    u_stride: u32,
    v_plane: *mut u8,
    v_stride: u32,
    rgba: *const u8,
    rgba_stride: u32,
    width: u32,
    height: u32,
    range: YuvRange,
    yuv_matrix: YuvMatrix,
    yuv_type: YuvType,
) {
    unsafe {
        let y_slice = slice::from_raw_parts_mut(y_plane, y_stride as usize * height as usize);
        let u_slice = if yuv_type == YuvType::Yuv420 {
            slice::from_raw_parts_mut(u_plane, u_stride as usize * (height as usize).div_ceil(2))
        } else {
            slice::from_raw_parts_mut(u_plane, u_stride as usize * height as usize)
        };
        let v_slice = if yuv_type == YuvType::Yuv420 {
            slice::from_raw_parts_mut(v_plane, v_stride as usize * (height as usize).div_ceil(2))
        } else {
            slice::from_raw_parts_mut(v_plane, v_stride as usize * height as usize)
        };
        let rgba_slice = slice::from_raw_parts(rgba, height as usize * rgba_stride as usize);

        let yuv_range = match range {
            YuvRange::Tv => yuv::YuvRange::Limited,
            YuvRange::Pc => yuv::YuvRange::Full,
        };

        let mut planar_image = YuvPlanarImageMut {
            y_plane: BufferStoreMut::Borrowed(y_slice),
            y_stride,
            u_plane: BufferStoreMut::Borrowed(u_slice),
            u_stride,
            v_plane: BufferStoreMut::Borrowed(v_slice),
            v_stride,
            width,
            height,
        };

        if yuv_matrix == YuvMatrix::Identity {
            assert_eq!(yuv_type, YuvType::Yuv444, "Identity exists only on 4:4:4");
            rgba_to_gbr(&mut planar_image, rgba_slice, rgba_stride, yuv_range).unwrap();
        } else if yuv_matrix == YuvMatrix::YCgCo {
            let callee = match yuv_type {
                YuvType::Yuv420 => rgba_to_ycgco420,
                YuvType::Yuv422 => rgba_to_ycgco422,
                YuvType::Yuv444 => rgba_to_ycgco444,
            };
            callee(&mut planar_image, rgba_slice, rgba_stride, yuv_range).unwrap();
        } else {
            let matrix = match yuv_matrix {
                YuvMatrix::Bt601 => YuvStandardMatrix::Bt601,
                YuvMatrix::Bt709 => YuvStandardMatrix::Bt709,
                YuvMatrix::Bt2020 => YuvStandardMatrix::Bt2020,
                YuvMatrix::Identity => unreachable!(),
                YuvMatrix::YCgCo => unreachable!(),
            };

            let callee = match yuv_type {
                YuvType::Yuv420 => rgba_to_yuv420,
                YuvType::Yuv422 => rgba_to_yuv422,
                YuvType::Yuv444 => rgba_to_yuv444,
            };

            callee(
                &mut planar_image,
                rgba_slice,
                rgba_stride,
                yuv_range,
                matrix,
                YuvConversionMode::Balanced,
            )
            .unwrap();
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn pixart_rgba8_to_y08(
    y_plane: *mut u8,
    y_stride: u32,
    rgba: *const u8,
    rgba_stride: u32,
    width: u32,
    height: u32,
    range: YuvRange,
    yuv_matrix: YuvMatrix,
) {
    unsafe {
        let y_slice = slice::from_raw_parts_mut(y_plane, y_stride as usize * height as usize);
        let rgba_slice = slice::from_raw_parts(rgba, height as usize * rgba_stride as usize);

        let yuv_range = match range {
            YuvRange::Tv => yuv::YuvRange::Limited,
            YuvRange::Pc => yuv::YuvRange::Full,
        };

        let mut planar_image = YuvGrayImageMut {
            y_plane: BufferStoreMut::Borrowed(y_slice),
            y_stride,
            width,
            height,
        };

        let matrix = match yuv_matrix {
            YuvMatrix::Bt601 => YuvStandardMatrix::Bt601,
            YuvMatrix::Bt709 => YuvStandardMatrix::Bt709,
            YuvMatrix::Bt2020 => YuvStandardMatrix::Bt2020,
            YuvMatrix::Identity => unreachable!(),
            YuvMatrix::YCgCo => unreachable!(),
        };
        rgba_to_yuv400(
            &mut planar_image,
            rgba_slice,
            rgba_stride,
            yuv_range,
            matrix,
        )
        .unwrap();
    }
}

#[inline(always)]
pub(crate) fn work_on_transmuted_ptr_u16<F>(
    rgba: *mut u16,
    rgba_stride: u32,
    width: usize,
    height: usize,
    copy: bool,
    cn: usize,
    mut lambda: F,
) where
    F: FnMut(&mut [u16], usize),
{
    let mut allocated = false;
    let mut dst_stride = rgba_stride as usize / 2;
    let mut working_slice: BufferStoreMut<'_, u16> = unsafe {
        if rgba as usize % 2 == 0 && rgba_stride % 2 == 0 {
            BufferStoreMut::Borrowed(slice::from_raw_parts_mut(
                rgba,
                rgba_stride as usize / 2 * height,
            ))
        } else {
            allocated = true;
            dst_stride = width * cn;

            let mut dst_slice = vec![0; width * height * cn];
            if copy {
                let src_slice =
                    slice::from_raw_parts(rgba as *mut u8, rgba_stride as usize * height);
                for (dst, src) in dst_slice
                    .chunks_exact_mut(dst_stride)
                    .zip(src_slice.chunks_exact(rgba_stride as usize))
                {
                    let src = &src[0..width * cn * 2];
                    let dst = &mut dst[0..width * cn];
                    for (dst, src) in dst.iter_mut().zip(src.chunks_exact(2)) {
                        *dst = u16::from_ne_bytes([src[0], src[1]]);
                    }
                }
            }
            BufferStoreMut::Owned(dst_slice)
        }
    };

    lambda(working_slice.borrow_mut(), dst_stride);

    if allocated {
        let src_slice = working_slice.borrow();
        let dst_slice =
            unsafe { slice::from_raw_parts_mut(rgba as *mut u8, rgba_stride as usize * height) };
        for (src, dst) in src_slice
            .chunks_exact(dst_stride)
            .zip(dst_slice.chunks_exact_mut(rgba_stride as usize))
        {
            let src = &src[0..width * cn];
            let dst = &mut dst[0..width * cn * 2];
            for (src, dst) in src.iter().zip(dst.chunks_exact_mut(2)) {
                let bytes = src.to_ne_bytes();
                dst[0] = bytes[0];
                dst[1] = bytes[1];
            }
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn pixart_rgba8_to_icgco_r10(
    y_plane: *mut u16,
    y_stride: u32,
    u_plane: *mut u16,
    u_stride: u32,
    v_plane: *mut u16,
    v_stride: u32,
    rgba: *const u8,
    rgba_stride: u32,
    width: u32,
    height: u32,
    range: YuvRange,
    r_type: AvifYCgCoRType,
    yuv_type: YuvType,
) {
    unsafe {
        let rgba_slice = slice::from_raw_parts(rgba, height as usize * rgba_stride as usize);

        let yuv_range = match range {
            YuvRange::Tv => yuv::YuvRange::Limited,
            YuvRange::Pc => yuv::YuvRange::Full,
        };

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

        work_on_transmuted_ptr_u16(
            y_plane,
            y_stride,
            width as usize,
            height as usize,
            false,
            1,
            |y_slice: &mut [u16], y_stride: usize| {
                work_on_transmuted_ptr_u16(
                    u_plane,
                    u_stride,
                    chroma_width,
                    chroma_height,
                    false,
                    1,
                    |u_slice: &mut [u16], u_stride: usize| {
                        work_on_transmuted_ptr_u16(
                            v_plane,
                            v_stride,
                            chroma_width,
                            chroma_height,
                            false,
                            1,
                            |v_slice: &mut [u16], v_stride: usize| {
                                let mut planar_image = YuvPlanarImageMut {
                                    y_plane: BufferStoreMut::Borrowed(y_slice),
                                    y_stride: y_stride as u32,
                                    u_plane: BufferStoreMut::Borrowed(u_slice),
                                    u_stride: u_stride as u32,
                                    v_plane: BufferStoreMut::Borrowed(v_slice),
                                    v_stride: v_stride as u32,
                                    width,
                                    height,
                                };

                                let callee = match yuv_type {
                                    YuvType::Yuv420 => match r_type {
                                        AvifYCgCoRType::Ro => rgba_to_icgc_ro010,
                                        AvifYCgCoRType::Re => rgba_to_icgc_re010,
                                    },
                                    YuvType::Yuv422 => match r_type {
                                        AvifYCgCoRType::Ro => rgba_to_icgc_ro210,
                                        AvifYCgCoRType::Re => rgba_to_icgc_re210,
                                    },
                                    YuvType::Yuv444 => match r_type {
                                        AvifYCgCoRType::Ro => rgba_to_icgc_ro410,
                                        AvifYCgCoRType::Re => rgba_to_icgc_re410,
                                    },
                                };

                                callee(&mut planar_image, rgba_slice, rgba_stride, yuv_range)
                                    .unwrap();
                            },
                        );
                    },
                );
            },
        );
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_yuv_encoding422() {
        let width = 550;
        let height = 333;
        let mut y_0 = vec![0u8; width * height];
        let mut u = vec![0u8; 275 * height.div_ceil(2)];
        let mut v = vec![0u8; 275 * height.div_ceil(2)];
        let rgba = vec![0u8; width * height * 4];
        pixart_rgba8_to_yuv8(
            y_0.as_mut_ptr(),
            width as u32,
            u.as_mut_ptr(),
            275,
            v.as_mut_ptr(),
            275,
            rgba.as_ptr(),
            width as u32 * 4,
            width as u32,
            height as u32,
            YuvRange::Pc,
            YuvMatrix::Bt601,
            YuvType::Yuv422,
        );
    }
}
