class_name BpmDetector
extends RefCounted

# Offline decoding uses Godot's own WAV/OGG/MP3 decoders; no audio is played.
const SAMPLE_RATE := 8000.0
const HOP := 32
const ENVELOPE_RATE := SAMPLE_RATE / HOP
const MIN_SECONDS := 8.0
const MIN_BPM := 30.0
const MAX_BPM := 300.0

var _mutex := Mutex.new()
var _cancelled := false
var _progress := 0


func cancel() -> void:
	_mutex.lock()
	_cancelled = true
	_mutex.unlock()


func progress() -> int:
	_mutex.lock()
	var value := _progress
	_mutex.unlock()
	return value


func _report(value: int) -> bool:
	_mutex.lock()
	_progress = value
	var active := not _cancelled
	_mutex.unlock()
	return active


func analyze(audio: AudioStream, preferred_bpm: float = 120.0) -> Dictionary:
	if audio == null:
		return {"error": "음원을 열 수 없어요. 음원 경로를 확인해 주세요."}
	var duration := audio.get_length()
	if not is_finite(duration) or duration < MIN_SECONDS:
		return {"error": "BPM을 찾으려면 8초 이상의 음원이 필요해요."}
	var playback := audio.instantiate_playback()
	if playback == null:
		return {"error": "이 음원을 분석할 수 없어요."}
	var envelope := PackedFloat32Array()
	var remaining := int(ceil(duration * SAMPLE_RATE))
	var total := remaining
	var low_left := 0.0
	var low_right := 0.0
	var energy := Vector3.ZERO
	var previous := Vector3.ZERO
	var count := 0
	playback.start()
	while remaining > 0:
		if not _report(int(60.0 * (total - remaining) / total)):
			playback.stop()
			return {"error": "cancelled"}
		var frames := playback.mix_audio(AudioServer.get_mix_rate() / SAMPLE_RATE, mini(4096, remaining))
		if frames.is_empty():
			break
		for frame in frames:
			low_left += 0.15 * (frame.x - low_left)
			low_right += 0.15 * (frame.y - low_right)
			# Keep stereo energies separate so opposite-phase channels cannot cancel.
			energy.x += frame.length_squared()
			energy.y += low_left * low_left + low_right * low_right
			energy.z += (frame.x - low_left) ** 2 + (frame.y - low_right) ** 2
			count += 1
			if count == HOP:
				var level := Vector3(sqrt(energy.x / HOP), sqrt(energy.y / HOP), sqrt(energy.z / HOP))
				var change := level - previous
				envelope.append(maxf(change.x, 0.0) + maxf(change.y, 0.0) + maxf(change.z, 0.0))
				previous = level
				energy = Vector3.ZERO
				count = 0
		remaining -= frames.size()
	playback.stop()
	if envelope.size() < int(MIN_SECONDS * ENVELOPE_RATE):
		return {"error": "음원을 끝까지 읽을 수 없어요. 다른 음원 파일로 다시 시도해 주세요."}
	var maximum := 0.0
	for value in envelope:
		maximum = maxf(maximum, value)
	if maximum > 0.0000001:
		for index in range(envelope.size()):
			envelope[index] /= maximum
	var peaks := _onsets(envelope)
	if peaks.size() < 8:
		return {"error": "규칙적인 박자를 찾지 못했어요. BPM을 직접 입력해 주세요."}
	preferred_bpm = clampf(preferred_bpm, MIN_BPM, MAX_BPM)
	var candidates := _tempo_candidates(envelope, preferred_bpm)
	if candidates.is_empty():
		return {"error": "BPM을 찾지 못했어요. BPM을 직접 입력해 주세요."}
	var best_bpm := 0.0
	var best_score := 0.0
	for index in range(candidates.size()):
		if not _report(80 + int(18.0 * index / candidates.size())):
			return {"error": "cancelled"}
		var center: float = candidates[index].bpm
		var radius := maxf(2.0, center * 0.025)
		var bpm := maxf(MIN_BPM, center - radius)
		var search_step := clampf(center * center / (240.0 * duration), 0.001, 0.05)
		var attempts := 0
		while bpm <= minf(MAX_BPM, center + radius):
			if attempts % 16 == 0 and not _report(80 + int(18.0 * index / candidates.size())):
				return {"error": "cancelled"}
			var score := _periodicity(peaks, bpm) * float(candidates[index].score) * _tempo_prior(bpm, preferred_bpm)
			if score > best_score:
				best_score = score
				best_bpm = bpm
			bpm += search_step
			attempts += 1
	if best_score < 0.015:
		return {"error": "박자가 불분명해서 BPM을 결정할 수 없어요. BPM을 직접 입력해 주세요."}
	# A whole-song phase fit avoids rounding to an integer autocorrelation lag.
	var refined := best_bpm
	var fine_score := _periodicity(peaks, best_bpm)
	for step in range(-60, 61):
		if step % 16 == 0 and not _report(98):
			return {"error": "cancelled"}
		var bpm := best_bpm + step * 0.001
		if bpm < MIN_BPM or bpm > MAX_BPM:
			continue
		var score := _periodicity(peaks, bpm)
		if score > fine_score:
			fine_score = score
			refined = bpm
	refined = _fit_beats(peaks, refined)
	if not _report(100):
		return {"error": "cancelled"}
	return {"error": "", "bpm": snappedf(clampf(refined, MIN_BPM, MAX_BPM), 0.001)}


func _onsets(envelope: PackedFloat32Array) -> Array[Vector2]:
	var prefix := PackedFloat64Array([0.0])
	var maximum := 0.0
	for value in envelope:
		prefix.append(prefix[-1] + value)
		maximum = maxf(maximum, value)
	var peaks: Array[Vector2] = []
	for index in range(1, envelope.size() - 1):
		var first := maxi(0, index - 125)
		var last := mini(envelope.size(), index + 126)
		var average := (prefix[last] - prefix[first]) / (last - first)
		var value := float(envelope[index])
		if value < maxf(0.0000001, maximum * 0.025) or value < average * 1.5:
			continue
		if value <= envelope[index - 1] or value < envelope[index + 1]:
			continue
		var denominator := envelope[index - 1] - 2.0 * value + envelope[index + 1]
		var shift := 0.5 * (envelope[index - 1] - envelope[index + 1]) / denominator if absf(denominator) > 0.000001 else 0.0
		var peak := Vector2((index + shift) / ENVELOPE_RATE, value * value)
		if not peaks.is_empty() and peak.x - peaks[-1].x < 0.06:
			if peak.y > peaks[-1].y:
				peaks[-1] = peak
		else:
			peaks.append(peak)
	return peaks


func _tempo_candidates(envelope: PackedFloat32Array, preferred_bpm: float) -> Array[Dictionary]:
	# Four distributed excerpts bound the coarse search cost on long songs.
	var blocks: Array[PackedFloat32Array] = []
	var length := mini(envelope.size(), 4000)
	var block_count := mini(4, maxi(1, int(ceil(float(envelope.size()) / length))))
	for block_index in range(block_count):
		var start := int(float(envelope.size() - length) * block_index / maxi(1, block_count - 1))
		var block := PackedFloat32Array()
		for index in range(start, start + length - 1, 2):
			block.append(envelope[index] + envelope[index + 1])
		blocks.append(block)
	var rate := ENVELOPE_RATE / 2.0
	var first_lag := int(floor(rate * 60.0 / MAX_BPM))
	var last_lag := int(ceil(rate * 60.0 / MIN_BPM))
	var correlations := PackedFloat64Array()
	correlations.resize(last_lag + 2)
	for lag in range(first_lag - 1, last_lag + 2):
		if not _report(60 + int(20.0 * (lag - first_lag) / (last_lag - first_lag + 1))):
			return []
		var product := 0.0
		var energy := 0.0
		for block in blocks:
			for index in range(lag, block.size()):
				product += block[index] * block[index - lag]
				energy += block[index] * block[index]
		correlations[lag] = product / maxf(energy, 0.000001)
	var candidates: Array[Dictionary] = []
	for lag in range(first_lag, last_lag + 1):
		var value := correlations[lag]
		if value <= correlations[lag - 1] or value < correlations[lag + 1]:
			continue
		var denominator := correlations[lag - 1] - 2.0 * value + correlations[lag + 1]
		var shift := 0.5 * (correlations[lag - 1] - correlations[lag + 1]) / denominator if absf(denominator) > 0.000001 else 0.0
		var bpm := clampf(rate * 60.0 / (lag + shift), MIN_BPM, MAX_BPM)
		# Repeated accent strengths help distinguish a beat from its subdivisions.
		candidates.append({"bpm": bpm, "score": value * (0.7 + 0.3 * _tempo_prior(bpm, preferred_bpm))})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) > float(b.score))
	return candidates.slice(0, 8)


func _tempo_prior(bpm: float, preferred_bpm: float) -> float:
	# Musical half/double-time is ambiguous. A rough existing BPM only resolves
	# that ambiguity; the actual fractional tempo comes from the audio.
	var octaves := log(bpm / preferred_bpm) / log(2.0)
	return exp(-2.0 * octaves * octaves)


func _periodicity(peaks: Array[Vector2], bpm: float) -> float:
	var fundamental := Vector2.ZERO
	var subdivision := Vector2.ZERO
	var weight := 0.0
	for peak in peaks:
		var phase := peak.x * bpm * TAU / 60.0
		var cosine := cos(phase)
		var sine := sin(phase)
		fundamental += Vector2(cosine, sine) * peak.y
		subdivision += Vector2(cosine * cosine - sine * sine, 2.0 * cosine * sine) * peak.y
		weight += peak.y
	return (fundamental.length_squared() + 0.35 * subdivision.length_squared()) / maxf(weight * weight, 0.000001)


func _fit_beats(peaks: Array[Vector2], bpm: float) -> float:
	var period := 60.0 / bpm
	for iteration in range(3):
		var phase_vector := Vector2.ZERO
		for peak in peaks:
			var phase := peak.x / period * TAU
			phase_vector += Vector2(cos(phase), sin(phase)) * peak.y
		var offset := atan2(phase_vector.y, phase_vector.x) / TAU
		var weight := 0.0
		var sum_x := 0.0
		var sum_y := 0.0
		var sum_xx := 0.0
		var sum_xy := 0.0
		var count := 0
		for peak in peaks:
			var beat := roundf(peak.x / period - offset)
			if absf(peak.x / period - offset - beat) > 0.12:
				continue
			weight += peak.y
			sum_x += peak.y * beat
			sum_y += peak.y * peak.x
			sum_xx += peak.y * beat * beat
			sum_xy += peak.y * beat * peak.x
			count += 1
		var denominator := weight * sum_xx - sum_x * sum_x
		if count < 8 or denominator < 0.000001:
			break
		var fitted := (weight * sum_xy - sum_x * sum_y) / denominator
		if fitted <= 0.0 or absf(fitted / period - 1.0) > 0.02:
			break
		period = fitted
	return 60.0 / period
