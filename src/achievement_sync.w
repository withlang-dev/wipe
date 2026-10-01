// Store-neutral upload bookkeeping. The game owns the achievement facts;
// this cache only avoids repeated platform calls within one session.
pub type AchievementSync {
    known: Vec[str],
    dirty: bool = false,
    waiting: bool = false,
    // Steam's callbacks have no request ID. Timed-out accepted stores still
    // count until acknowledged, so a late callback cannot confirm a retry.
    pending_stores: u64 = 0,
    retry_at: f64 = 0.0,
    deadline: f64 = 0.0,
    failures: i32 = 0,
}

pub fn AchievementSync.new() -> AchievementSync:
    AchievementSync { known: Vec.new() }

extend AchievementSync:
    pub fn needs(self: &Self, id: &str) -> bool: not self.known.contains(id)

    // Call only after a successful query of an unlocked achievement or a
    // successful set. A failed query/set must remain eligible next time.
    pub fn remember(mut self: Self, id: &str, changed: bool):
        if self.needs(id): self.known.push(id.clone())
        if changed: self.dirty = true

    fn retry(mut self: Self, now: f64):
        self.dirty = true
        self.failures += 1
        if self.failures > 6: self.failures = 6
        var delay = 1.0
        for _ in 0..self.failures: delay *= 2.0
        if delay > 60.0: delay = 60.0
        self.retry_at = now + delay

    // End this wait window, but retain the unacknowledged accepted store.
    // Losing a callback keeps retrying with bounded backoff, never falsely clean.
    pub fn tick(mut self: Self, now: f64):
        if self.waiting and now >= self.deadline:
            self.waiting = false
            self.retry(now)

    pub fn ready(self: &Self, now: f64) -> bool:
        self.dirty and not self.waiting and now >= self.retry_at

    pub fn submitted(mut self: Self, accepted: bool, now: f64):
        if not accepted:
            self.retry(now)
            return
        self.pending_stores += 1
        self.waiting = true
        self.dirty = false
        self.deadline = now + 15.0

    pub fn completed(mut self: Self, ok: bool, invalidated: bool, now: f64):
        let tracked = self.pending_stores > 0
        if tracked: self.pending_stores -= 1
        // InvalidParam means Steam replaced rejected values with its own.
        // Forget the observations so the next snapshot reconciles them.
        if invalidated: self.known.clear()
        if not ok or invalidated:
            // A failure may belong to an older request too. Preserve the
            // latest wait/deadline while any accepted store remains pending.
            if self.pending_stores == 0: self.waiting = false
            self.retry(now)
            return
        // An unsolicited success cannot cancel a rejected submission's
        // backoff. An ambiguous success cannot finish the latest wait.
        if not tracked or self.pending_stores > 0: return
        self.waiting = false
        self.failures = 0
        self.retry_at = 0.0
        // Do not clear dirty here: another unlock may have arrived while
        // this request was in flight and still needs its own store.

    pub fn flush(mut self: Self): self.retry_at = 0.0
