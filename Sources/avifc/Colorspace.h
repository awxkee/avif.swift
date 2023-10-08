//
//  Colorspace.h
//
//
//  Created by Radzivon Bartoshyk on 07/10/2023.
//

#ifndef Colorspace_h
#define Colorspace_h

#import <vector>

// https://64.github.io/tonemapping/

using namespace std;

static const float REC_709_PRIMARIES[3][2]  = { { 0.640, 0.330 }, { 0.300, 0.600 }, { 0.150, 0.060 } };
static const float REC_2020_PRIMARIES[3][2] = { { 0.708, 0.292 }, { 0.170, 0.797 }, { 0.131, 0.046 } };
static const float DCI_P3_PRIMARIES[3][2] = { { 0.740, 0.270 }, { 0.220, 0.780 }, { 0.090, -0.090 } };

static const float ILLUMINANT_D65[2] = { 0.3127, 0.3290 };

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

const vector<vector<float>> inverse(const vector<vector<float>> m)
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

std::vector<float> div(const std::vector<float>& numerator, const std::vector<float>& denominator) {
    if (numerator.size() != denominator.size()) {
        throw std::invalid_argument("Vectors must have the same size for division.");
    }

    std::vector<float> result;
    result.reserve(numerator.size());

    for (size_t i = 0; i < numerator.size(); ++i) {
        if (denominator[i] == 0.0) {
//            throw std::invalid_argument("Division by zero is not allowed.");
            result.push_back(0.0f);
        } else {
            result.push_back(numerator[i] / denominator[i]);
        }
    }

    return result;
}

std::vector<float> clamp(const std::vector<float>& inputVector, float minValue, float maxValue) {
    std::vector<float> result;
    result.reserve(inputVector.size());

    for (const float& element : inputVector) {
        float clampedValue = (element < minValue) ? minValue : (element > maxValue) ? maxValue : element;
        result.push_back(clampedValue);
    }

    return result;
}

vector<float> xy_to_xyz(const float x, const float y)
{
    vector<float> ret(3, 0.0f);

    ret[0] = x / y;
    ret[1] = 1.0;
    ret[2] = (1.0 - x - y) / y;

    return ret;
}

const vector<float> get_d65_xyz()
{
    return xy_to_xyz(ILLUMINANT_D65[0], ILLUMINANT_D65[1]);
}

vector<float> add(const vector<float>& vec, const float scalar) {
    vector<float> result(vec.size());
    copy(vec.begin(), vec.end(), result.begin());
    for (float& element : result) {
        element += scalar;
    }
    return result;
}

vector<float> mul(const vector<float>& vec, const float scalar) {
    vector<float> result(vec.size());
    copy(vec.begin(), vec.end(), result.begin());
    for (float& element : result) {
        element *= scalar;
    }
    return result;
}

std::vector<std::vector<float>> transposeMatrix(const std::vector<std::vector<float>>& matrix) {
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


const vector<vector<float>> get_primaries_xyz(const float primaries_xy[3][2])
{
    // Columns: R G B
    // Rows: X Y Z
    vector<vector<float>> ret(3, std::vector<float>(3, 0.0f));

    ret[0] = xy_to_xyz(primaries_xy[0][0], primaries_xy[0][1]);
    ret[1] = xy_to_xyz(primaries_xy[1][0], primaries_xy[1][1]);
    ret[2] = xy_to_xyz(primaries_xy[2][0], primaries_xy[2][1]);

    return transposeMatrix(ret);
}

std::vector<float> mul(const std::vector<std::vector<float>>& matrix, const std::vector<float>& vector) {
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

std::vector<float> mul(const std::vector<float>& vector1, const std::vector<float>& vector2) {
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

std::vector<std::vector<float>> mul(const std::vector<std::vector<float>>& matrix1, const std::vector<std::vector<float>>& matrix2) {
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


const vector<vector<float>> gamut_rgb_to_xyz_matrix(const float primaries_xy[3][2])
{
    const vector<vector<float>> xyz_matrix = get_primaries_xyz(primaries_xy);
    const vector<float> white_xyz = get_d65_xyz();
    const vector<float> s = mul(inverse(xyz_matrix), white_xyz);
    const vector<vector<float>> m = { mul(xyz_matrix[0], s), mul(xyz_matrix[1], s), mul(xyz_matrix[2], s) };
    return m;
}

static const vector<vector<float>> gamut_xyz_color_matrix_2020 = gamut_rgb_to_xyz_matrix(REC_2020_PRIMARIES);
static const vector<vector<float>> gamut_xyz_color_matrix_709  = gamut_rgb_to_xyz_matrix(REC_709_PRIMARIES);
static const vector<vector<float>> gamut_xyz_color_matrix_dciP3 = gamut_rgb_to_xyz_matrix(DCI_P3_PRIMARIES);
static const vector<vector<float>> convert_matrix_2020_to_709  = mul(inverse(gamut_xyz_color_matrix_709), gamut_xyz_color_matrix_2020);
static const vector<vector<float>> convert_matrix_2020_to_dciP3  = mul(inverse(gamut_xyz_color_matrix_dciP3), gamut_xyz_color_matrix_2020);
static const vector<vector<float>> convert_matrix_DCIP3_to_709  = mul(inverse(gamut_xyz_color_matrix_709), gamut_xyz_color_matrix_dciP3);

static const vector<vector<float>> inverseRec2020 = inverse(gamut_xyz_color_matrix_2020);
static const vector<vector<float>> inverseDisplayP3 = inverse(gamut_xyz_color_matrix_dciP3);

inline vector<float> Colorspace_Gamut_Conversion_2020_to_DCIP3(const vector<float>& rgb)
{
    return mul(convert_matrix_2020_to_dciP3, rgb);
}

inline vector<float> Colorspace_Gamut_Conversion_2020_to_709(const vector<float>& rgb)
{
    return mul(convert_matrix_2020_to_709, rgb);
}

inline vector<float> Colorspace_Gamut_Conversion_DCIP3_to_709(const vector<float>& rgb)
{
    return mul(convert_matrix_DCIP3_to_709, rgb);
}

static const std::vector<vector<float>> aces_input_matrix =
{
    {0.59719f, 0.35458f, 0.04823f},
    {0.07600f, 0.90834f, 0.01566f},
    {0.02840f, 0.13383f, 0.83777f}
};

static const std::vector<vector<float>> aces_output_matrix =
{
    { 1.60475f, -0.53108f, -0.07367f},
    {-0.10208f,  1.10813f, -0.00605f},
    {-0.00327f, -0.07276f,  1.07602f}
};

vector<float> rtt_and_odt_fit(vector<float> v)
{
    vector<float> a = add(mul(v, add(v, 0.0245786f)), - 0.000090537f);
    vector<float> b = mul(mul(v, add(mul(v, 0.983729f), 0.4329510f)), 0.238081f);
    return div(a, b);
}

vector<float> aces_approx(const vector<float>& v)
{
    vector<float> r = mul(v, 0.6f);
    float a = 2.51f;
    float b = 0.03f;
    float c = 2.43f;
    float d = 0.59f;
    float e = 0.14f;
    auto num = mul(r,add(mul(r,a),b));
    auto den = add(mul(r, add(mul(r, c), d)), e);
    auto ret = clamp(div(num, den), 0.0f, 1.0f);
    return ret;
}

vector<float> aces_fitted(vector<float>& v)
{
    v = mul(aces_input_matrix, v);
    v = rtt_and_odt_fit(v);
    return mul(aces_output_matrix, v);
}

std::vector<float> acesFilmicToneMapping(const std::vector<float>& rgb) {
    std::vector<float> result(3);
    for (int i = 0; i < 3; ++i) {
        result[i] = (rgb[i] * (2.51f * rgb[i] + 0.03f)) / (rgb[i] * (2.43f * rgb[i] + 0.59f) + 0.14f);
    }
    return result;
}

// Uncharted 2 tone mapping function
std::vector<float> uncharted2ToneMapping(const std::vector<float>& rgb) {
    std::vector<float> result(3);
    const float A = 0.15f;
    const float B = 0.50f;
    const float C = 0.10f;
    const float D = 0.20f;
    const float E = 0.02f;
    const float F = 0.30f;
    for (int i = 0; i < 3; ++i) {
        result[i] = (rgb[i] * (A * rgb[i] + C * B) + D * E) / (rgb[i] * (A * rgb[i] + B) + D * F);
    }
    return result;
}

// Hejl Richard tone mapping function
std::vector<float> hejlRichardToneMapping(const std::vector<float>& rgb) {
    std::vector<float> result(3);
    for (int i = 0; i < 3; ++i) {
        result[i] = std::max(0.0f, (rgb[i] * (2.0f * rgb[i] + 0.049f)) / (rgb[i] * (2.0f * rgb[i] + 0.247f) + 0.0092f));
    }
    return result;
}

std::vector<float> dragoToneMapping(const std::vector<float>& rgb, float bias = 0.85) {
    std::vector<float> result(3);
    for (int i = 0; i < 3; ++i) {
        result[i] = std::log(1.0 + bias * rgb[i]) / std::log(1.0 + bias);
    }
    return result;
}

// Filmic Uncharted 3 tone mapping function
std::vector<float> filmicUncharted3ToneMapping(const std::vector<float>& rgb) {
    std::vector<float> result(3);
    for (int i = 0; i < 3; ++i) {
        result[i] = (rgb[i] * (2.0f * rgb[i] + 0.30f)) / (rgb[i] * (2.0f * rgb[i] + 2.0f) + 0.02f);
    }
    return result;
}

std::vector<float> reinhard(const std::vector<float>& rgb) {
    return div(rgb, add(rgb, 1.0f));
}

float reinhard(const float v) {
    return v / (1.0f + v);
}

inline float Luma(const vector<float>& v, const float* primaries) {
    return v[0] * primaries[0] + v[1] * primaries[1] + v[2] * primaries[2];
}

vector<float> change_luminance(const vector<float>& c_in, float l_out, const float* primaries)
{
    float l_in = Luma(c_in, primaries);
    const float scale = l_out / l_in;
    return { c_in[0]*scale, c_in[1]*scale, c_in[2]*scale };
}

vector<float> reinhard_extended_luminance(const vector<float>& v, float max_white_l, const float* primaries)
{
    float l_old = Luma(v, primaries);
    float numerator = l_old * (1.0f + (l_old / (max_white_l * max_white_l)));
    float l_new = numerator / (1.0f + l_old);
    return change_luminance(v, l_new, primaries);
}

template <typename T>
T lerp(const T& a, const T& b, float t) {
    return a + t * (b - a);
}

vector<float> reinhard_jodie(const vector<float>& v, const float* primaries)
{
    float l = Luma(v, primaries);
    vector<float> tv = { v[0] / (1.0f + v[0]), v[1] / (1.0f + v[1]) , v[2] / (1.0f + v[2])};
    vector<float> res = { lerp(v[0] / (1.0f + l), tv[0], tv[0]), lerp(v[1] / (1.0f + l), tv[1], tv[1]), lerp(v[2] / (1.0f + l), tv[2], tv[2]) };
    return res;
}

float uncharted2_tonemap_partial(float x)
{
    float A = 0.15f;
    float B = 0.50f;
    float C = 0.10f;
    float D = 0.20f;
    float E = 0.02f;
    float F = 0.30f;
    return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

float uncharted2_filmic(float v)
{
    float exposure_bias = 2.0f;
    float curr = uncharted2_tonemap_partial(v * exposure_bias);

    float W = 11.2f;
    float white_scale = 1.0f / uncharted2_tonemap_partial(W);
    return curr * white_scale;
}


// Apply the Hable tone mapping operator to a single HDR pixel
inline float hableToneMapping(float x) {
    const float A = 0.15f;    // Shoulder Strength
    const float B = 0.50f;    // Linear Strength
    const float C = 0.10f;    // Linear Angle
    const float D = 0.20f;    // Toe Strength
    const float E = 0.02f;    // Toe Numerator
    const float F = 0.30f;    // Toe Denominator
    return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

inline float hable(float x)
{
    const float A = 0.15, B = 0.50, C = 0.10, D = 0.20, E = 0.02, F = 0.30;

    return ((x * (A * x + (C * B)) + (D * E)) / (x * (A * x + B) + (D * F))) - E / F;
}

inline float ToneMappingHable(const float rgb)
{
    static const float HABLE_DIV = hable(4.8);
    return hable(rgb) / HABLE_DIV;
}

#endif /* Colorspace_h */
