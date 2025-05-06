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
use crate::support::{SliceStoreMut, transmute_const_ptr16};
use std::slice;

#[unsafe(no_mangle)]
pub extern "C-unwind" fn pixart_rgba_u16_to_f16(
    source_f16: *const u16,
    f16_stride: u32,
    target_f16: *mut u16,
    target_f16_stride: u32,
    bit_depth: u32,
    width: u32,
    height: u32,
) {
    unsafe {
        let f16_container = transmute_const_ptr16(
            source_f16,
            f16_stride as usize,
            width as usize,
            height as usize,
            4,
        );

        let rgba_slice8 = slice::from_raw_parts_mut(
            target_f16 as *mut u8,
            height as usize * target_f16_stride as usize,
        );
        let mut is_owned_rgba = false;
        let rgba_stride_u16;

        let mut working_slice = if let Ok(casted) = bytemuck::try_cast_slice_mut(rgba_slice8) {
            rgba_stride_u16 = target_f16_stride / 2;
            SliceStoreMut::Borrowed(casted)
        } else {
            is_owned_rgba = true;
            rgba_stride_u16 = width * 4;
            SliceStoreMut::Owned(vec![0u16; width as usize * 4 * height as usize])
        };

        yuv::convert_rgba16_to_f16(
            f16_container.0.as_ref(),
            f16_container.1,
            bytemuck::cast_slice_mut(working_slice.borrow_mut()),
            rgba_stride_u16 as usize,
            bit_depth as usize,
            width as usize,
            height as usize,
        )
        .unwrap();

        let target = slice::from_raw_parts_mut(
            target_f16 as *mut u8,
            height as usize * target_f16_stride as usize,
        );
        if is_owned_rgba {
            for (dst, src) in target.chunks_exact_mut(target_f16_stride as usize).zip(
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
pub extern "C-unwind" fn pixart_rgb_u16_to_f16(
    source_f16: *const u16,
    f16_stride: u32,
    target_f16: *mut u16,
    target_f16_stride: u32,
    bit_depth: u32,
    width: u32,
    height: u32,
) {
    unsafe {
        let f16_container = transmute_const_ptr16(
            source_f16,
            f16_stride as usize,
            width as usize,
            height as usize,
            3,
        );

        let rgba_slice8 = slice::from_raw_parts_mut(
            target_f16 as *mut u8,
            height as usize * target_f16_stride as usize,
        );
        let mut is_owned_rgba = false;
        let rgba_stride_u16;

        let mut working_slice = if let Ok(casted) = bytemuck::try_cast_slice_mut(rgba_slice8) {
            rgba_stride_u16 = target_f16_stride / 2;
            SliceStoreMut::Borrowed(casted)
        } else {
            is_owned_rgba = true;
            rgba_stride_u16 = width * 3;
            SliceStoreMut::Owned(vec![0u16; width as usize * 3 * height as usize])
        };

        yuv::convert_rgb16_to_f16(
            f16_container.0.as_ref(),
            f16_container.1,
            bytemuck::cast_slice_mut(working_slice.borrow_mut()),
            rgba_stride_u16 as usize,
            bit_depth as usize,
            width as usize,
            height as usize,
        )
        .unwrap();

        let target = slice::from_raw_parts_mut(
            target_f16 as *mut u8,
            height as usize * target_f16_stride as usize,
        );
        if is_owned_rgba {
            for (dst, src) in target.chunks_exact_mut(target_f16_stride as usize).zip(
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
