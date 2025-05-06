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
#![allow(clippy::missing_safety_doc)]
#![feature(f16)]
mod ar30;
mod cvt_f16;
mod rgb_to_yuv;
mod scaling;
mod support;
mod yuv_to_rgb;

pub use ar30::{pixart_rgb_u16_to_ra30, pixart_rgba_u16_to_ra30};
pub use cvt_f16::{pixart_rgb_u16_to_f16, pixart_rgba_u16_to_f16};
pub use rgb_to_yuv::{pixart_rgba8_to_icgco_r10, pixart_rgba8_to_y08, pixart_rgba8_to_yuv8};
pub use scaling::{pixart_scale_plane_u8, pixart_scale_plane_u16};
pub use yuv_to_rgb::{
    AvifYCgCoRType, YuvMatrix, YuvRange, YuvType, pixart_icgc_r_alpha12_to_rgba10,
    pixart_icgc_r_type_to_rgb, pixart_icgc_r_type_with_alpha_to_rgba, pixart_icgc12_r_to_rgb10,
    pixart_yuv8_to_rgb8, pixart_yuv8_with_alpha_to_rgba8, pixart_yuv16_to_rgb16,
    pixart_yuv16_to_rgba_f16, pixart_yuv16_with_alpha_to_rgba16, pixart_yuv400_p16_to_rgb16,
    pixart_yuv400_p16_with_alpha_to_rgba16, pixart_yuv400_to_rgb8,
    pixart_yuv400_with_alpha_to_rgba8,
};
