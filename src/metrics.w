// Fixed-memory histograms keep instrumentation out of the allocation path.
// Bucket values are upper bounds in 0.25 ms increments; 50 ms is overflow.
pub type Metric {
    count: i32 = 0, total: f64 = 0.0, peak: f64 = 0.0,
    bins: [i32; 201] = [0; 201],
}
extend Metric:
    pub fn add(mut self: Self, milliseconds: f64) -> Unit:
        self.count += 1
        self.total += milliseconds
        if milliseconds > self.peak: self.peak = milliseconds
        let bucket = if milliseconds >= 50.0: 200 else: (milliseconds * 4.0) as i32
        self.bins[bucket] += 1

    pub fn percentile(self: &Self, percent: i32) -> f64:
        let target = (self.count * percent + 99) / 100
        var seen = 0
        for i in 0..201:
            seen += self.bins[i]
            if seen >= target: return if i == 200: self.peak else: (i as f64 + 1.0) / 4.0
        50.0

    pub fn report(self: &Self, name: &str) -> Unit:
        if self.count == 0: return
        print(f"{name}: samples={self.count} mean_ms={self.total / self.count as f64} p50_ms<={self.percentile(50)} p95_ms<={self.percentile(95)} p99_ms<={self.percentile(99)} max_ms={self.peak}")
