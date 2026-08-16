/* Vinnie's Oil Australia — portal idle-timeout
   Auto signs-out a logged-in reseller/admin after a period of no page
   activity, rather than keeping sessions alive indefinitely (Supabase's
   default). Call startIdleTimer(supabaseClient, minutes, loginPath) once
   the page has confirmed the user is authenticated. */
function startIdleTimer(supabaseClient, timeoutMinutes, loginPath) {
  var timer;
  var events = ['mousemove', 'keydown', 'click', 'scroll', 'touchstart'];

  function reset() {
    clearTimeout(timer);
    timer = setTimeout(async function () {
      try { await supabaseClient.auth.signOut(); } catch (e) { /* ignore */ }
      window.location.href = loginPath + '?reason=idle';
    }, timeoutMinutes * 60 * 1000);
  }

  events.forEach(function (evt) {
    document.addEventListener(evt, reset, { passive: true });
  });
  reset();
}
