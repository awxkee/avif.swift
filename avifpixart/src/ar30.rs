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
use crate::support::transmute_const_ptr16;
use std::slice;
use yuv::Rgb30ByteOrder;

#[unsafe(no_mangle)]
pub extern "C" fn pixart_rgba_u16_to_ra30(
    source_u16: *const u16,
    u16_stride: u32,
    ar30_dst: *mut u8,
    ar30_stride: u32,
    bit_depth: u32,
    width: u32,
    height: u32,
) {
    unsafe {
        let f16_container = transmute_const_ptr16(
            source_u16,
            u16_stride as usize,
            width as usize,
            height as usize,
            4,
        );

        let ar30_slice =
            slice::from_raw_parts_mut(ar30_dst, height as usize * ar30_stride as usize);

        if bit_depth == 10 {
            yuv::rgba10_to_ra30(
                ar30_slice,
                ar30_stride,
                Rgb30ByteOrder::Network,
                f16_container.0.as_ref(),
                f16_container.1 as u32,
                width,
                height,
            )
            .unwrap();
        } else if bit_depth == 12 {
            yuv::rgba12_to_ra30(
                ar30_slice,
                ar30_stride,
                Rgb30ByteOrder::Network,
                f16_container.0.as_ref(),
                f16_container.1 as u32,
                width,
                height,
            )
            .unwrap();
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn pixart_rgb_u16_to_ra30(
    source_u16: *const u16,
    u16_stride: u32,
    ar30_dst: *mut u8,
    ar30_stride: u32,
    bit_depth: u32,
    width: u32,
    height: u32,
) {
    unsafe {
        let f16_container = transmute_const_ptr16(
            source_u16,
            u16_stride as usize,
            width as usize,
            height as usize,
            3,
        );

        let ar30_slice =
            slice::from_raw_parts_mut(ar30_dst, height as usize * ar30_stride as usize);

        if bit_depth == 10 {
            yuv::rgb10_to_ra30(
                ar30_slice,
                ar30_stride,
                Rgb30ByteOrder::Network,
                f16_container.0.as_ref(),
                f16_container.1 as u32,
                width,
                height,
            )
            .unwrap();
        } else if bit_depth == 12 {
            yuv::rgb12_to_ra30(
                ar30_slice,
                ar30_stride,
                Rgb30ByteOrder::Network,
                f16_container.0.as_ref(),
                f16_container.1 as u32,
                width,
                height,
            )
            .unwrap();
        }
    }
}
