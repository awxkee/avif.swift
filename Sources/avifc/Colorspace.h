//
//  NEMath.h
//  avif.swift [https://github.com/awxkee/avif.swift]
//
//  Created by Radzivon Bartoshyk on 07/10/2023.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#ifndef Colorspace_h
#define Colorspace_h

#import <vector>
#import "NEMath.h"

// https://64.github.io/tonemapping/
// https://www.russellcottrell.com/photo/matrixCalculator.htm

using namespace std;

#if defined(__clang__)
#pragma clang fp contract(fast) exceptions(ignore) reassociate(on)
#endif

static const float Rec709Primaries[3][2]  = { { 0.640, 0.330 }, { 0.300, 0.600 }, { 0.150, 0.060 } };
static const float Rec2020Primaries[3][2] = { { 0.708, 0.292 }, { 0.170, 0.797 }, { 0.131, 0.046 } };
static const float DisplayP3Primaries[3][2] = { { 0.740, 0.270 }, { 0.220, 0.780 }, { 0.090, -0.090 } };

static const float IlluminantD65[2] = { 0.3127, 0.3290 };

static vector<float> add(const vector<float>& vec, const float scalar) {
    vector<float> result(vec.size());
    copy(vec.begin(), vec.end(), result.begin());
    for (float& element : result) {
        element += scalar;
    }
    return result;
}

static vector<float> mul(const vector<float>& vec, const float scalar) {
    vector<float> result(vec.size());
    copy(vec.begin(), vec.end(), result.begin());
    for (float& element : result) {
        element *= scalar;
    }
    return result;
}

static std::vector<float> mul(const std::vector<std::vector<float>>& matrix, const std::vector<float>& vector) {
    if (matrix.size() != 3 || matrix[0].size() != 3 || vector.size() != 3) {
        throw std::invalid_argument("Matrix must be 3x3 and vector must have size 3");
    }

    std::vector<float> result(3, 0.0f);

    for (int i = 0; i < 3; ++i) {
        for (int j = 0; j < 3; ++j) {
            result[i] += matrix[i][j] * vector[j];
        }
    }

    return result;
}

static std::vector<float> mul(const std::vector<float>& vector1, const std::vector<float>& vector2) {
    if (vector1.size() != 3 || vector2.size() != 3) {
        // Check for valid dimensions
        throw std::invalid_argument("Vectors must be of size 3.");
    }

    std::vector<float> result(3);

    for (int i = 0; i < 3; i++) {
        result[i] = vector1[i] * vector2[i];
    }

    return result;
}

static std::vector<std::vector<float>> mul(const std::vector<std::vector<float>>& matrix1, const std::vector<std::vector<float>>& matrix2) {
    auto rows1 = matrix1.size();
    auto cols1 = matrix1[0].size();
    auto rows2 = matrix2.size();
    auto cols2 = matrix2[0].size();

    if (cols1 != rows2) {
        // Check if the number of columns in the first matrix is equal to the number of rows in the second matrix
        throw std::invalid_argument("Number of columns in the first matrix must be equal to the number of rows in the second matrix.");
    }

    std::vector<std::vector<float>> result(rows1, std::vector<float>(cols2, 0.0f));

    for (int i = 0; i < rows1; ++i) {
        for (int j = 0; j < cols2; ++j) {
            for (int k = 0; k < cols1; ++k) {
                result[i][j] += matrix1[i][k] * matrix2[k][j];
            }
        }
    }

    return result;
}

class ColorSpaceMatrix {
public:
    ColorSpaceMatrix(const float primariesXy[3][2], const float whitePoint[2]) {
        vector<vector<float>> mt = GamutRgbToXYZ(primariesXy, whitePoint);
        matrix = reinterpret_cast<float*>(malloc(sizeof(float)*9));
        SetVector(mt);
    }

    ColorSpaceMatrix(const vector<vector<float>> source) {
        matrix = reinterpret_cast<float*>(malloc(sizeof(float)*9));
        SetVector(source);
    }

    ~ColorSpaceMatrix() {
        free(matrix);
    }

#if __arm64__

    inline float32x4_t transfer(const float32x4_t v) {
        const float32x4_t row1 = { matrix[0], matrix[1], matrix[2], 0.0f };
        const float32x4_t row2 = { matrix[3], matrix[4], matrix[5], 0.0f };
        const float32x4_t row3 = { matrix[6], matrix[7], matrix[8], 0.0f };

        return vaddq_f32(vaddq_f32(vmulq_f32(v, row1), vmulq_f32(v, row2)), vmulq_f32(v, row3));
    }

    inline float32x4_t operator*(const float32x4_t v) {
        const float32x4_t row1 = { matrix[0], matrix[1], matrix[2], 0.0f };
        const float32x4_t row2 = { matrix[3], matrix[4], matrix[5], 0.0f };
        const float32x4_t row3 = { matrix[6], matrix[7], matrix[8], 0.0f };

        return vaddq_f32(vaddq_f32(vmulq_f32(v, row1), vmulq_f32(v, row2)), vmulq_f32(v, row3));
    }

    inline float32x4x4_t operator*(const float32x4x4_t v) {
        const float32x4_t r1 = vaddq_f32(vaddq_f32(vmulq_f32(v.val[0], row1), vmulq_f32(v.val[0], row2)), vmulq_f32(v.val[1], row3));
        const float32x4_t r2 = vaddq_f32(vaddq_f32(vmulq_f32(v.val[1], row1), vmulq_f32(v.val[1], row2)), vmulq_f32(v.val[1], row3));
        const float32x4_t r3 = vaddq_f32(vaddq_f32(vmulq_f32(v.val[2], row1), vmulq_f32(v.val[2], row2)), vmulq_f32(v.val[2], row3));
        const float32x4_t r4 = vaddq_f32(vaddq_f32(vmulq_f32(v.val[3], row1), vmulq_f32(v.val[3], row2)), vmulq_f32(v.val[3], row3));
        float32x4x4_t r = { r1, r2, r3, r4 };
        return r;
    }

#endif

    ColorSpaceMatrix operator*(const ColorSpaceMatrix& other) {
        vector<vector<float>> resultMatrix(3, vector<float>(3, 0.0f));

        for (size_t i = 0; i < 3; ++i) {
            for (size_t j = 0; j < 3; ++j) {
                for (size_t k = 0; k < 3; ++k) {
                    resultMatrix[i][j] += matrix[i*3 + k] * other.matrix[k*3 + j];
                }
            }
        }

        return ColorSpaceMatrix(resultMatrix);
    }

    inline void convert(float& r, float& g, float& b) {
#if __arm64
        float32x4_t v = { r, g, b, 0.0f };
        v = vaddq_f32(vaddq_f32(vmulq_f32(v, row1), vmulq_f32(v, row2)), vmulq_f32(v, row3));
        r = vgetq_lane_f32(v, 0);
        g = vgetq_lane_f32(v, 1);
        b = vgetq_lane_f32(v, 2);
#else
        const float newR = matrix[0]*r + matrix[1]*g + matrix[2]*b;
        const float newG = matrix[3]*r + matrix[4]*g + matrix[5]*b;
        const float newB = matrix[6]*r + matrix[7]*g + matrix[8]*b;
        r = newR;
        g = newG;
        b = newB;
#endif
    }

    void inverse() {
        vector<vector<float>> ret(3, std::vector<float>(3, 0.0f));
        for (int i = 0; i < 3; ++i) {
            for (int j = 0; j < 3; ++j) {
                ret[i][j] = matrix[i*3 + j];
            }
        }
        ret = inverseVector(ret);
        SetVector(ret);
    }

    ColorSpaceMatrix inverted() {
        vector<vector<float>> ret(3, std::vector<float>(3, 0.0f));
        for (int i = 0; i < 3; ++i) {
            for (int j = 0; j < 3; ++j) {
                ret[i][j] = matrix[i*3 + j];
            }
        }
        ret = inverseVector(ret);
        return ColorSpaceMatrix(ret);
    }

    vector<float> XyToXYZ(const float x, const float y)
    {
        vector<float> ret(3, 0.0f);

        ret[0] = x / y;
        ret[1] = 1.0;
        ret[2] = (1.0 - x - y) / y;

        return ret;
    }

    const vector<float> getWhitePoint(const float whitePoint[2])
    {
        return XyToXYZ(whitePoint[0], whitePoint[1]);
    }

    vector<vector<float>> GamutRgbToXYZ(const float primariesXy[3][2], const float whitePoint[2])
    {
        const vector<vector<float>> xyZMatrix = getPrimariesXYZ(primariesXy);
        const vector<float> whiteXyz = getWhitePoint(whitePoint);
        const vector<float> s = mul(inverseVector(xyZMatrix), whiteXyz);
        const vector<vector<float>> m = { mul(xyZMatrix[0], s), mul(xyZMatrix[1], s), mul(xyZMatrix[2], s) };
        return m;
    }
private:
    float* matrix;

#if __arm64__
    float32x4_t row1;
    float32x4_t row2;
    float32x4_t row3;
#endif

    void SetVector(const vector<vector<float>> m) {
        for (int i = 0; i < 3; ++i) {
            for (int j = 0; j < 3; ++j) {
                matrix[i*3 + j] = m[i][j];
            }
        }

#if __arm64
        row1 = { matrix[0], matrix[1], matrix[2], 0.0f };
        row2 = { matrix[3], matrix[4], matrix[5], 0.0f };
        row3 = { matrix[6], matrix[7], matrix[8], 0.0f };
#endif
    }

    const vector<vector<float>> inverseVector(const vector<vector<float>> m)
    {
        vector<vector<float>> ret(3, std::vector<float>(3, 0.0f));
        const float det = determinant(m);
        ret[0][0] = det2(m[1][1], m[1][2], m[2][1], m[2][2]) / det;
        ret[0][1] = det2(m[0][2], m[0][1], m[2][2], m[2][1]) / det;
        ret[0][2] = det2(m[0][1], m[0][2], m[1][1], m[1][2]) / det;
        ret[1][0] = det2(m[1][2], m[1][0], m[2][2], m[2][0]) / det;
        ret[1][1] = det2(m[0][0], m[0][2], m[2][0], m[2][2]) / det;
        ret[1][2] = det2(m[0][2], m[0][0], m[1][2], m[1][0]) / det;
        ret[2][0] = det2(m[1][0], m[1][1], m[2][0], m[2][1]) / det;
        ret[2][1] = det2(m[0][1], m[0][0], m[2][1], m[2][0]) / det;
        ret[2][2] = det2(m[0][0], m[0][1], m[1][0], m[1][1]) / det;
        return ret;
    }

    const vector<vector<float>> getPrimariesXYZ(const float primaries_xy[3][2])
    {
        // Columns: R G B
        // Rows: X Y Z
        vector<vector<float>> ret(3, std::vector<float>(3, 0.0f));

        ret[0] = XyToXYZ(primaries_xy[0][0], primaries_xy[0][1]);
        ret[1] = XyToXYZ(primaries_xy[1][0], primaries_xy[1][1]);
        ret[2] = XyToXYZ(primaries_xy[2][0], primaries_xy[2][1]);

        return transpose(ret);
    }

    const float det2(const float a00, const float a01, const float a10, const float a11)
    {
        return a00 * a11 - a01 * a10;
    }

    const float determinant(const vector<vector<float>> m)
    {
        float det = 0;

        det += m[0][0] * det2(m[1][1], m[1][2], m[2][1], m[2][2]);
        det -= m[0][1] * det2(m[1][0], m[1][2], m[2][0], m[2][2]);
        det += m[0][2] * det2(m[1][0], m[1][1], m[2][0], m[2][1]);

        return det;
    }

    std::vector<std::vector<float>> transpose(const std::vector<std::vector<float>>& matrix) {
        if (matrix.size() != 3 || matrix[0].size() != 3) {
            throw std::invalid_argument("Input matrix must be 3x3");
        }

        std::vector<std::vector<float>> result(3, std::vector<float>(3, 0.0f));

        for (int i = 0; i < 3; ++i) {
            for (int j = 0; j < 3; ++j) {
                result[i][j] = matrix[j][i];
            }
        }

        return result;
    }

};

inline float Luma(const vector<float>& v, const float* primaries) {
    return v[0] * primaries[0] + v[1] * primaries[1] + v[2] * primaries[2];
}

template <typename T>
T lerp(const T& a, const T& b, float t) {
    return a + t * (b - a);
}

#endif /* Colorspace_h */
