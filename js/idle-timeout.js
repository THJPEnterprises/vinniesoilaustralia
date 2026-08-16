/* Vinnie's Oil Australia — portal idle-timeout
   Auto signs-out a logged-in reseller/admin after a period of no page
   activity, rather than keeping sessions alive indefinitely (Supabase's
   default). Call startIdleTimer(supabaseClient, minutes, loginPath) once
   the page has confirmed the user is authenticated.

   The elapsed time is tracked via a localStorage timestamp rather than
   relying solely on a live setTimeout, because mobile browsers commonly
   suspend a backgrounded tab's JavaScript entirely (to save battery) —
   a phone locked overnight means the setTimeout callback may simply
   never get to run. localStorage survives that suspension, so as soon
   as the tab becomes visible/focused again we can check real elapsed
   time and log out immediately if it's overdue, instead of silently
   staying logged in forever. */
function startIdleTimer(supabaseClient, timeoutMinutes, loginPath) {
  var timeoutMs = timeoutMinutes * 60 * 1000;
  var storageKey = 'voa_last_activity';
  var timer;
  var loggedOut = false;
  var events = ['mousemove', 'keydown', 'click', 'scroll', 'touchstart'];

  function recordActivity() {
    try { localStorage.setItem(storageKey, String(Date.now())); } catch (e) { /* ignore */ }
  }

  async function doLogout() {
    if (loggedOut) return;
    loggedOut = true;
    try { await supabaseClient.auth.signOut(); } catch (e) { /* ignore */ }
    try { localStorage.removeItem(storageKey); } catch (e) { /* ignore */ }
    window.location.href = loginPath + '?reason=idle';
  }

  // Compares real wall-clock elapsed time against the last recorded
  // activity. Returns true (and logs out) if the timeout has passed —
  // this is what catches a tab that was backgrounded/suspended through
  // the actual timeout window.
  function checkElapsed() {
    var stored = Number(localStorage.getItem(storageKey));
    var last = stored || Date.now();
    if (Date.now() - last >= timeoutMs) {
      doLogout();
      return true;
    }
    return false;
  }

  function reset() {
    if (loggedOut) return;
    recordActivity();
    clearTimeout(timer);
    timer = setTimeout(checkElapsed, timeoutMs);
  }

  events.forEach(function (evt) {
    document.addEventListener(evt, reset, { passive: true });
  });

  // Re-check on anything that indicates the tab/app just became active
  // again — this is the fallback that works even when the setTimeout
  // above never fired because the page was suspended in the background.
  document.addEventListener('visibilitychange', function () {
    if (document.visibilityState === 'visible' && !checkElapsed()) reset();
  });
  window.addEventListener('pageshow', function () {
    if (!checkElapsed()) reset();
  });
  window.addEventListener('focus', function () {
    if (!checkElapsed()) reset();
  });

  recordActivity();
  reset();
}
