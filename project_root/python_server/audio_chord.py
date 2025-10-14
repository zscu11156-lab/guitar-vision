# audio_chord.py
# 支援和弦集合（與影像辨識一致）：
# ['Am','Am7','B','Bm','C','Cadd9','D','D7_F#','Dsus4','Em','Em7','G']

import numpy as np
import librosa

# -------- 和弦集合（12 個） --------
CHORD_SET = ['Am','Am7','B','Bm','C','Cadd9','D','D7_F#','Dsus4','Em','Em7','G']

# 半音索引：C=0, C#=1, D=2, ...
_NOTE2IDX = {
    'C':0, 'C#':1, 'Db':1, 'D':2, 'D#':3, 'Eb':3, 'E':4,
    'F':5, 'F#':6, 'Gb':6, 'G':7, 'G#':8, 'Ab':8, 'A':9,
    'A#':10, 'Bb':10, 'B':11
}

def _tpl_notes(notes, boost_note=None, boost_gain=0.5):
    """
    依和弦所含音名建立 12 維模板；可選擇對特定低音做微加權（for 斜線和弦）。
    最後做 L2 normalize。
    """
    v = np.zeros(12, dtype=float)
    for n in notes:
        v[_NOTE2IDX[n]] += 1.0
    if boost_note:
        v[_NOTE2IDX[boost_note]] += float(boost_gain)
    v /= (np.linalg.norm(v) + 1e-9)
    return v

# -------- 12 個和弦的模板 --------
_TEMPLATES = {
    'Am':     _tpl_notes(['A','C','E']),
    'Am7':    _tpl_notes(['A','C','E','G']),
    'B':      _tpl_notes(['B','D#','F#']),
    'Bm':     _tpl_notes(['B','D','F#']),
    'C':      _tpl_notes(['C','E','G']),
    'Cadd9':  _tpl_notes(['C','E','G','D']),
    'D':      _tpl_notes(['D','F#','A']),
    # D7/F#：以 D7（D F# A C）為基底，稍微強化低音 F#
    'D7_F#':  _tpl_notes(['D','F#','A','C'], boost_note='F#', boost_gain=0.5),
    'Dsus4':  _tpl_notes(['D','G','A']),
    'Em':     _tpl_notes(['E','G','B']),
    'Em7':    _tpl_notes(['E','G','B','D']),
    'G':      _tpl_notes(['G','B','D']),
}

def _cossim(u, v):
    return float(np.dot(u, v) / ((np.linalg.norm(u) * np.linalg.norm(v)) + 1e-9))

# ---------- 即時 1 秒窗（挑戰模式用） ----------
def classify_pcm16le(pcm_bytes: bytes, sr: int = 44100, hop: int = 1024):
    """
    輸入：1.0 秒 mono 16-bit 小端 PCM（≈ sr*2 bytes）
    回傳：(chord, conf, energy)
    """
    x = np.frombuffer(pcm_bytes, dtype='<i2').astype(np.float32) / 32768.0
    if x.size == 0:
        return 'NC', 0.0, 0.0

    # 去 DC + 能量（RMS）
    x = x - np.mean(x)
    energy = float(np.sqrt(np.mean(x**2)))
    if energy < 0.02:  # 撥弦能量門檻（可視環境微調）
        return 'NC', 0.0, energy

    # 和聲/打擊分離 + CQT chroma（逐幀 L2 normalize）
    y_h, _ = librosa.effects.hpss(x)
    C = librosa.feature.chroma_cqt(y=y_h, sr=sr, hop_length=hop)     # [12, T]
    C = C / (np.linalg.norm(C, axis=0, keepdims=True) + 1e-9)

    # 1 秒窗取平均向量並 L2 normalize，讓 cosine 相似度更穩
    c_mean = np.mean(C, axis=1)
    c_mean = c_mean / (np.linalg.norm(c_mean) + 1e-9)

    # 與模板做 cosine similarity
    sims = {ch: _cossim(c_mean, _TEMPLATES[ch]) for ch in CHORD_SET}
    chord = max(sims, key=sims.get)
    conf  = float(sims[chord])  # 0~1

    return chord, conf, energy

# ---------- 整首檔案（歌曲模式可選） ----------
def decode_file_to_segments(filepath: str, sr=None, hop: int = 1024, beats_sec=None):
    """
    1) 整首做 chroma
    2) 逐幀對模板 cos sim → argmax
    3) 平滑（多數決 + 最短長度）
    4) 若有 beats_sec：以每拍投票，輸出 (start, end, chord)
       否則用連續幀合併
    """
    y, sr = librosa.load(filepath, sr=sr, mono=True)
    y_h, _ = librosa.effects.hpss(y)
    C = librosa.feature.chroma_cqt(y=y_h, sr=sr, hop_length=hop)     # [12, F]
    C = C / (np.linalg.norm(C, axis=0, keepdims=True) + 1e-9)

    # chordgram
    templates = np.stack([_TEMPLATES[ch] for ch in CHORD_SET], axis=0)  # [K,12]
    sims = (C.T @ templates.T)                                          # [F,K]
    idx = np.argmax(sims, axis=1)                                       # [F]
    labels = [CHORD_SET[i] for i in idx]

    # 平滑
    labels = _majority_filter(labels, win=7)
    labels = _min_run(labels, min_len=5)

    if beats_sec and len(beats_sec) >= 2:
        return _segments_by_beats(labels, sr, hop, beats_sec)
    else:
        return _segments_by_runs(labels, sr, hop)

def _majority_filter(seq, win=7):
    if win % 2 == 0: win += 1
    half = win // 2
    out = seq[:]
    for i in range(half, len(seq)-half):
        window = seq[i-half:i+half+1]
        out[i] = max(set(window), key=window.count)
    return out

def _min_run(seq, min_len=5):
    if not seq: return seq
    out = seq[:]
    s = 0
    while s < len(out):
        e = s
        while e < len(out) and out[e] == out[s]: e += 1
        if e - s < min_len:
            fill = out[e] if e < len(out) else (out[s-1] if s > 0 else out[s])
            for k in range(s, e): out[k] = fill
        s = e
    return out

def _segments_by_runs(labels, sr, hop):
    times = librosa.frames_to_time(np.arange(len(labels)+1), sr=sr, hop_length=hop)
    segs = []
    s = 0; cur = labels[0]
    for i in range(1, len(labels)):
        if labels[i] != cur:
            segs.append((float(times[s]), float(times[i]), cur))
            cur = labels[i]; s = i
    segs.append((float(times[s]), float(times[len(labels)]), cur))
    return segs

def _segments_by_beats(labels, sr, hop, beats_sec):
    # 把逐幀標籤以每拍投票
    frame_times = librosa.frames_to_time(np.arange(len(labels)), sr=sr, hop_length=hop)
    segs = []
    for i in range(len(beats_sec)-1):
        t0, t1 = beats_sec[i], beats_sec[i+1]
        mask = (frame_times >= t0) & (frame_times < t1)
        if not np.any(mask):
            continue
        candidates = [labels[j] for j, m in enumerate(mask) if m]
        ch = max(set(candidates), key=candidates.count)
        if segs and segs[-1][2] == ch:
            s,e,_ = segs[-1]
            segs[-1] = (s, t1, ch)
        else:
            segs.append((t0, t1, ch))
    return segs
