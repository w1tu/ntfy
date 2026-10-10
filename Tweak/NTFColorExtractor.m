#import "NTFColorExtractor.h"

#define NTF_SAMPLE_SIZE 32
#define NTF_HUE_BINS 24

typedef struct {
	double weight;
	double r, g, b;
	NSUInteger count;
} NTFHueBin;

static void NTFRGBToHSV(double r, double g, double b, double *h, double *s, double *v) {
	double max = fmax(r, fmax(g, b));
	double min = fmin(r, fmin(g, b));
	double delta = max - min;
	*v = max;
	*s = max > 0 ? delta / max : 0;
	if (delta <= 0) {
		*h = 0;
		return;
	}
	double hue;
	if (max == r) hue = fmod((g - b) / delta, 6.0);
	else if (max == g) hue = (b - r) / delta + 2.0;
	else hue = (r - g) / delta + 4.0;
	hue /= 6.0;
	*h = hue < 0 ? hue + 1.0 : hue;
}

static NSInteger NTFHueBinIndex(double hue) {
	return MIN((NSInteger)(hue * NTF_HUE_BINS), NTF_HUE_BINS - 1);
}

static NSInteger NTFBestBin(const double *scores) {
	NSInteger best = -1;
	double bestScore = 0;
	for (NSInteger i = 0; i < NTF_HUE_BINS; i++) {
		double score = scores[i]
			+ 0.5 * scores[(i + NTF_HUE_BINS - 1) % NTF_HUE_BINS]
			+ 0.5 * scores[(i + 1) % NTF_HUE_BINS];
		if (score > bestScore) {
			bestScore = score;
			best = i;
		}
	}
	return best;
}

UIColor *NTFRepresentativeColor(UIImage *image) {
	CGImageRef cgImage = image.CGImage;
	if (!cgImage) return nil;

	const size_t side = NTF_SAMPLE_SIZE;
	uint8_t pixels[NTF_SAMPLE_SIZE * NTF_SAMPLE_SIZE * 4] = {0};
	CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
	CGContextRef context = CGBitmapContextCreate(pixels, side, side, 8, side * 4, space,
	                                             kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
	CGColorSpaceRelease(space);
	if (!context) return nil;
	CGContextSetInterpolationQuality(context, kCGInterpolationMedium);
	CGContextDrawImage(context, CGRectMake(0, 0, side, side), cgImage);
	CGContextRelease(context);

	NTFHueBin bins[NTF_HUE_BINS] = {{0}};
	NSUInteger opaque = 0, chromatic = 0, neutral = 0;
	double neutralR = 0, neutralG = 0, neutralB = 0;

	for (size_t i = 0; i < side * side; i++) {
		uint8_t alpha = pixels[i * 4 + 3];
		if (alpha < 128) continue;
		opaque++;

		double a = alpha / 255.0;
		double r = pixels[i * 4] / 255.0 / a;
		double g = pixels[i * 4 + 1] / 255.0 / a;
		double b = pixels[i * 4 + 2] / 255.0 / a;
		r = fmin(r, 1); g = fmin(g, 1); b = fmin(b, 1);

		double h, s, v;
		NTFRGBToHSV(r, g, b, &h, &s, &v);

		if (s >= 0.22 && v >= 0.22) {
			double weight = s * (0.35 + 0.65 * v);
			NTFHueBin *bin = &bins[NTFHueBinIndex(h)];
			bin->weight += weight;
			bin->r += r * weight;
			bin->g += g * weight;
			bin->b += b * weight;
			bin->count++;
			chromatic++;
		} else if (v >= 0.2 && v <= 0.85) {
			neutralR += r; neutralG += g; neutralB += b;
			neutral++;
		}
	}

	if (opaque == 0) return nil;

	if (chromatic >= MAX((NSUInteger)6, opaque * 3 / 100)) {
		double scores[NTF_HUE_BINS];
		for (NSInteger i = 0; i < NTF_HUE_BINS; i++) scores[i] = bins[i].weight;
		NSInteger best = NTFBestBin(scores);
		if (best >= 0) {
			double weight = 0, r = 0, g = 0, b = 0;
			for (NSInteger offset = -1; offset <= 1; offset++) {
				NTFHueBin bin = bins[(best + offset + NTF_HUE_BINS) % NTF_HUE_BINS];
				double factor = offset == 0 ? 1.0 : 0.5;
				weight += bin.weight * factor;
				r += bin.r * factor;
				g += bin.g * factor;
				b += bin.b * factor;
			}
			if (weight > 0) return [UIColor colorWithRed:r / weight green:g / weight blue:b / weight alpha:1];
		}
	}

	// greys are fine (settings icon), pure black/white falls back
	if (neutral > 0 && neutral * 100 >= opaque * 35) {
		return [UIColor colorWithRed:neutralR / neutral green:neutralG / neutral blue:neutralB / neutral alpha:1];
	}
	return nil;
}

UIColor *NTFDominantColorAmong(NSArray<UIColor *> *colors) {
	if (colors.count == 0) return nil;
	if (colors.count == 1) return colors.firstObject;

	double counts[NTF_HUE_BINS] = {0};
	NSInteger binForColor[colors.count];
	for (NSUInteger i = 0; i < colors.count; i++) {
		CGFloat h = 0, s = 0, v = 0, a = 0;
		binForColor[i] = -1;
		if ([colors[i] getHue:&h saturation:&s brightness:&v alpha:&a] && s >= 0.2) {
			binForColor[i] = NTFHueBinIndex(h);
			counts[binForColor[i]] += 1;
		}
	}

	NSInteger best = NTFBestBin(counts);
	double r = 0, g = 0, b = 0, total = 0;
	for (NSUInteger i = 0; i < colors.count; i++) {
		NSInteger bin = binForColor[i];
		BOOL member = best < 0
			? bin < 0
			: bin >= 0 && (bin == best || bin == (best + 1) % NTF_HUE_BINS || bin == (best + NTF_HUE_BINS - 1) % NTF_HUE_BINS);
		if (!member) continue;
		CGFloat cr = 0, cg = 0, cb = 0, ca = 0;
		if (![colors[i] getRed:&cr green:&cg blue:&cb alpha:&ca]) continue;
		r += cr; g += cg; b += cb;
		total += 1;
	}
	if (total == 0) return colors.firstObject;
	return [UIColor colorWithRed:r / total green:g / total blue:b / total alpha:1];
}

UIColor *NTFPastelColor(UIColor *color) {
	CGFloat h = 0, s = 0, v = 0, a = 0;
	if (![color getHue:&h saturation:&s brightness:&v alpha:&a]) return color;
	return [UIColor colorWithHue:h saturation:s * 0.5 brightness:MAX(v, 0.92) alpha:a];
}
