// ackshually screen mockups: single source for screens.html (gallery) and ../spec.html.
// Edit a screen here and both pages update. Each screen: t = title, ms = milestone, li = interaction bullets, h = phone HTML.
const chrome = (title, right='⋯') => `<div class="notch"></div><div class="status"><span>9:41</span><span>●●● ▮</span></div>
  <div class="nav"><span class="a">‹ Games</span><b>${title}</b><span class="a">${right}</span></div>`;
const pageGeneral = `<div class="page"><h5>5 · Bureaucracy</h5><p>Players earn money for each city they power this round.</p>
  <p><span class="hl"><b>End of turn:</b> discard all unused energy</span> back to the supply.</p><p>Resources stored on plants are not affected.</p><div class="fig"></div></div>`;
const pageBattery = (hl=true) => `<div class="page"><h5>7 · Items</h5><p>Items are bought during phase 3 and stay in front of you.</p>
  <p>${hl?'<span class="hl">':''}<b>Battery:</b> at end of turn, you may keep up to 2 unused energy.${hl?'</span>':''}</p><p>Only one Battery per player. Items cannot be traded.</p><div class="fig"></div><p>See also: Phase 4, Resources.</p></div>`;
const head = `<div class="head"><div class="rq">3 energy + a Battery, at end of turn</div>
  <div class="verdict">Keep 2 energy, discard 1.</div>
  <div class="meta"><span class="chip">✓ Stated · p.12, p.14</span><span class="chip alt">No Battery? Discard 3 ›</span></div></div>`;
const c1 = (peek)=>`<div class="card${peek?' peek':''}"><div class="h"><b>1 · General rule</b><span>p.12</span></div>Unused energy is discarded at end of turn.</div>`;
const c2 = (peek)=>`<div class="card${peek?' peek':''}"><div class="h"><b>2 · Exception</b><span>p.14</span></div>The Battery keeps up to 2 unused energy, overriding the discard.</div>`;
const c3 = (peek)=>`<div class="card${peek?' peek':''}"><div class="h"><b>3 · Your 3 energy</b><span>p.14</span></div>2 stay on the Battery, 1 goes back to the supply.</div>`;
// Follow-up + thumbs: their own row under the shelf (2026-11-21), not a closing "Result" card.
const footer = `<div class="fb" style="margin:6px 11px 0"><span style="flex:4;text-align:left;padding-left:8px;color:var(--muted)">Ask a follow-up</span><span>👍</span><span>👎</span></div>`;
const dots = n => `<div class="dots">${[0,1,2].map(i=>`<i${i===n?' class="on"':''}></i>`).join('')}</div>`;

const S = [
 {t:'1 · My Games', ms:'Home · M2 (sessions + export in M3)', li:['App <b>opens here</b>; most recently used first','<b>Tap a game</b> → viewer, Back returns here','<b>＋</b> → file picker → new game, or add to a game','<b>Swipe left</b> → Delete'],
  h:`<div class="notch"></div><div class="status"><span>9:41</span><span>●●● ▮</span></div><div class="home">
   <div style="display:flex;justify-content:space-between;color:var(--accent);font-size:13px;margin:2px 0 4px"><span>⚙︎</span><span>＋</span></div>
   <div style="font-size:19px;font-weight:700;margin-bottom:8px">My Games</div>
   <div class="game"><div class="cover" style="background:#fff;border:1px solid var(--line)"></div><div style="flex:1"><b>Power plant rush</b><span>Opened 2 minutes ago</span></div><span style="color:var(--muted)">›</span></div>
   <div class="game"><div class="cover" style="background:#fff;border:1px solid var(--line)"></div><div style="flex:1"><b>Azul</b><span>Opened yesterday</span></div><span style="color:var(--muted)">›</span></div>
   <div class="game" style="padding-right:56px"><div class="cover" style="background:#fff;border:1px solid var(--line)"></div><div><b>Root</b><span>7 rulebooks</span></div><div class="swipeacts"><span style="background:#a2412b">Delete</span></div></div>
   <div class="game"><div class="cover" style="background:#fff;border:1px solid var(--line)"></div><div style="flex:1"><b>Dune Imperium</b><span>Opened 3 weeks ago</span></div><span style="color:var(--muted)">›</span></div>
   </div>
   <div class="gest" style="top:232px;left:56px">← swipe</div>`},

 {t:'2 · New game, preparing', ms:'M2 basic · M3 background OCR', li:['PDF <b>readable instantly</b>','Asking is <b>never blocked</b>','Status line only if pages need OCR'],
  h:`${chrome('Azul')}<div class="page"><h5>Overview</h5><p>Introduced by the Moors, azulejos were tile works…</p><div class="fig" style="height:90px"></div><p>Players take turns drafting tiles from the factory displays…</p></div>
   <div style="position:absolute;left:12px;right:12px;bottom:52px;z-index:6;font-size:8.5px;color:var(--muted);display:flex;align-items:center;gap:6px"><span style="flex:1;height:3px;border-radius:2px;background:var(--line);overflow:hidden"><i style="display:block;width:38%;height:100%;background:var(--accent)"></i></span>Reading scanned pages 3/8</div>
   <div class="ask">Ask about the rules…<span class="mic">🎙</span></div>`},

 {t:'3 · Ask: hold to talk', ms:'Viewer idle · M2', li:['<b>Hold 🎙</b>: live transcript, <b>release</b> sends','<b>Slide left</b> cancels','<b>Tap 🎙</b>: dictation, edit before sending'],
  h:`${chrome('Power Grid')}${pageGeneral.replace('<span class="hl">','<span>')}
   <div class="ask" style="flex-direction:column;align-items:stretch;gap:5px;padding:8px 8px 8px 10px;border-radius:16px;color:var(--ink)">
    <div>“what happens to my energy at end of turn if I have the batt…”</div>
    <div style="display:flex;align-items:center;gap:8px;color:var(--muted)"><span>‹ slide to cancel</span><div class="wave" style="margin-left:auto"><i style="height:4px"></i><i style="height:10px"></i><i style="height:14px"></i><i style="height:7px"></i><i style="height:11px"></i><i style="height:5px"></i></div><span class="mic" style="margin-left:0;transform:scale(1.25)">🎙</span></div></div>
   <div class="tap" style="bottom:12px;right:9px"></div><div class="gest" style="bottom:72px;right:8px">hold</div>`},

 {t:'4 · Answer arriving (t≈1s)', ms:'Streaming · M2', li:['<b>Restated question</b> first','Wrong? <b>Stop</b> and rephrase right away','Verdict streams in next'],
  h:`${chrome('Power Grid')}${pageGeneral.replace('<span class="hl">','<span>')}
   <div class="sheet"><div class="grab"></div><div class="head">
    <div class="rq">You asked</div><div style="font-size:11px;font-weight:600;margin-bottom:8px">3 energy + a Battery, at end of turn</div>
    <div class="skel" style="width:85%;height:13px"></div><div class="skel" style="width:45%"></div>
    <div style="display:flex;justify-content:space-between;align-items:center;margin-top:10px"><span style="color:var(--muted)">Reading the rulebook…</span><span class="btn g">■ Stop</span></div></div></div>
   <div class="tap" style="bottom:4px;right:14px;width:44px"></div>`},

 {t:'5 · Verdict + step 1 (t≈5s)', ms:'Sheet · M2', li:['Fixed <b>answer header</b>: verdict, confidence, branch','<b>Step card</b> below; PDF jumps + highlights','Peeking card = <b>swipe or tap</b> for next'],
  h:`${chrome('Power Grid')}${pageGeneral}<div class="sheet"><div class="grab"></div>${head}
   <div class="rail">${c1()}${c2(true)}</div>${dots(0)}</div>
   <div class="gest" style="bottom:50px;right:6px">← swipe or tap</div>`},

 {t:'6 · Step 2', ms:'Sheet · M2', li:['Header <b>never changes</b> while stepping','PDF <b>follows the card</b>: page turn + zoom','<b>Swipe right</b> / tap left peek = back'],
  h:`${chrome('Power Grid')}${pageBattery()}<div class="sheet"><div class="grab"></div>${head}
   <div class="rail mid">${c1(true)}${c2()}${c3(true)}</div>${dots(1)}${footer}</div>
   <div class="gest" style="top:150px;left:50%;transform:translateX(-50%)">page follows the card</div>`},

 {t:'7 · Show the skeptic', ms:'Sheet collapsed · M2', li:['<b>Drag sheet down</b>: page near full-screen','Verdict stays pinned as one line','Drag up to restore'],
  h:`${chrome('Power Grid')}${pageBattery()}
   <div class="sheet" style="padding:7px 11px 12px"><div class="grab"></div><div style="display:flex;justify-content:space-between;align-items:center"><b style="font-size:11.5px">Keep 2 energy, discard 1.</b><span class="chip" style="font-size:7.5px;white-space:nowrap">✓ p.14</span></div></div>
   <div class="gest" style="bottom:52px;left:50%;transform:translateX(-50%)">drag down ↓</div>`},

 {t:'8 · Inspect freely', ms:'M2', li:['<b>Pinch / pan</b> anytime','<b>Double-tap</b>: back to the highlight, or evidence ↔ full page'],
  h:`${chrome('Power Grid')}<div class="page" style="padding-top:20px"><p>…Phase 3: buy resources in reverse order.</p><h5>7 · Items</h5><p>Items are bought during phase 3 and stay in front of you.</p><p><span class="hl"><b>Battery:</b> at end of turn…</span></p></div>
   <div class="sheet"><div class="grab"></div>${head}<div class="rail mid">${c1(true)}${c2()}${c3(true)}</div></div>
   <div class="gest" style="top:120px;right:14px">pinch / pan</div>`},

 {t:'9 · Full answer', ms:'Sheet expanded · M2', li:['<b>Drag up</b>: everything about the answer','<b>Tap a step</b> → jump to it','<b>Tap the branch</b> → its own step cards'],
  h:`${chrome('Power Grid')}${pageBattery()}
   <div class="sheet" style="top:48px"><div class="grab"></div>${head}
    <div class="head"><div class="sect" style="margin-top:2px">Steps</div>
     <div class="steprow"><div>1 · General rule</div><span>p.12</span></div>
     <div class="steprow on"><div>2 · Exception</div><span>p.14</span></div>
     <div class="steprow"><div>3 · Your 3 energy</div><span>p.14</span></div>
     <div class="sect">Assumes</div><div style="color:var(--muted)">The Battery is already in play.</div></div></div>
   <div class="gest" style="top:52px;right:10px">drag up ↑</div>`},

 {t:'10 · Not covered → web', ms:'M4', li:['Auto when <b>Not covered / Inferred</b>','Web source = a <b>labeled card</b>, never a PDF highlight','Conflict: rulebook leads, <b>⚠ Designer disagrees</b>'],
  h:`${chrome('Root')}<div class="page"><h5>4.2 · Battle</h5><p>The attacker chooses a clearing where they have warriors or pieces.</p><p><span class="hl">4.2.1 The defender may ambush…</span></p><p>Rolls are resolved with the higher die going to the attacker.</p></div>
   <div class="sheet"><div class="grab"></div><div class="head"><div class="rq">Can the Vagabond move after battling?</div>
    <div class="verdict">Probably yes; the Law doesn't say.</div>
    <div class="meta"><span class="chip alt">? Not covered · closest 4.2</span></div></div>
    <div class="rail mid">${'<div class="card peek"><div class="h"><b>1 · Closest rule</b><span>4.2</span></div>…</div>'}
     <div class="card web"><div class="warnl">⚠ Designer disagrees</div><div class="h"><span>🌐 bgg.com · 2021</span><span>↗</span></div>“Yes, as long as he has boots.”</div>
     <div class="card peek"><div class="h"><b>3</b></div>…</div></div>${dots(1)}</div>`},

 {t:'11 · 👎 feedback', ms:'Feedback row · M3', li:['<b>👍</b> saved silently','<b>👎</b>: one-tap reason, optional step + note','⋯ → <b>Export game</b> as JSON'],
  h:`${chrome('Power Grid')}${pageBattery()}<div class="dim"></div>
   <div class="modal"><div class="grab"></div><b style="font-size:11.5px">What was wrong?</b>
    <div class="opts" style="margin-top:4px"><span>Wrong verdict</span><span>Missed exception</span><span class="on">Wrong highlight</span><span>Wrong page</span><span>Too slow</span><span>Other</span></div>
    <div style="margin-top:7px;color:var(--muted)">Which step? <span class="opts"><span>1</span><span class="on">2</span><span>3</span></span></div>
    <div class="note">Note (optional)…</div>
    <div style="text-align:right;margin-top:8px"><span class="btn">Send</span></div></div>`},

 {t:'12 · Sessions', ms:'⋯ → Sessions · M3', li:['<b>Tap a question</b> → reopens it at step 1','<b>New</b> = new game night, clears context'],
  h:`<div class="notch"></div><div class="status"><span>9:41</span><span>●●● ▮</span></div>
   <div class="nav"><span class="a">‹ Power Grid</span><b>Sessions</b><span class="a">New</span></div>
   <div class="home" style="top:52px">
    <div class="sect">Tonight</div>
    <div class="qrow"><div>Energy with a Battery at end of turn?</div><div>Keep 2, discard 1 · 👍</div></div>
    <div class="qrow"><div>Can I buy a plant I can't power?</div><div>Yes, but you must discard one · 👎</div></div>
    <div class="sect">Nov 14</div>
    <div class="qrow"><div>When does step 3 start?</div><div>When the Step 3 card is drawn</div></div>
    <div class="qrow"><div>Ties in turn order?</div><div>Highest plant number goes first</div></div></div>
   <div class="tap" style="top:24px;right:2px;width:34px"></div>`}
,
 {t:'13 · Playing with', ms:'Opening a game with add-ons · M3', li:['Shows <b>every time</b> a game has add-ons','Core books always on; <b>tap</b> an add-on to tick it','Starts from last time: <b>Play</b> is one tap','<b>Swipe left</b> → Remove · long-press → Make Core / Add-on, Rename','Viewer title button changes it mid-game'],
  h:`${chrome('My Games')}
   <div class="sheet" style="top:58px;padding:10px 12px">
    <div style="display:flex;justify-content:space-between;align-items:center"><span style="color:var(--muted)">✕</span><span style="text-align:center;line-height:1.1"><b style="font-size:12px">Root</b><br><span style="color:var(--muted);font-size:8.5px">Playing with</span></span><span class="btn">Play</span></div>
    <div class="sect">Core</div>
    <div class="qrow" style="display:flex;align-items:center;gap:6px;padding:5px 8px;margin-bottom:4px"><span style="flex:1">Law of Root</span><span style="width:10px;color:var(--muted);font-weight:700">✓</span></div>
    <div class="qrow" style="display:flex;align-items:center;gap:6px;padding:5px 8px;margin-bottom:4px"><span style="flex:1">Learning to Play</span><span style="width:10px;color:var(--muted);font-weight:700">✓</span></div>
    <div class="sect">Add-ons</div>
    <div class="qrow" style="display:flex;align-items:center;gap:6px;padding:5px 8px;margin-bottom:4px"><span style="flex:1">Riverfolk</span><span style="width:10px;color:var(--accent);font-weight:700">✓</span></div>
    <div class="qrow" style="display:flex;align-items:center;gap:6px;padding:5px 8px;margin-bottom:4px"><span style="flex:1">Underworld</span><span style="width:10px;color:var(--accent);font-weight:700"></span></div>
    <div class="qrow" style="display:flex;align-items:center;gap:6px;padding:5px 8px;margin-bottom:4px"><span style="flex:1">Marauder</span><span style="width:10px;color:var(--accent);font-weight:700"></span></div>
    <div class="qrow" style="display:flex;align-items:center;gap:6px;padding:5px 8px;margin-bottom:4px"><span style="flex:1">Homeland</span><span style="width:10px;color:var(--accent);font-weight:700"></span></div>
    <div class="qrow" style="display:flex;align-items:center;gap:6px;padding:5px 8px;margin-bottom:4px"><span style="flex:1">Law of Rootbotics</span><span style="width:10px;color:var(--accent);font-weight:700">✓</span></div>
    <div class="qrow" style="padding:5px 8px;color:var(--accent)">＋ Add a Rulebook</div>
    </div>
   <div class="tap" style="top:186px;right:10px;width:26px"></div>`}
];

// Render: gallery into #grid, or any element with data-screen="s5" (phone only, or with notes if data-notes is set).
function screenCard(s,i,withTitle=true){
  return `<div class="item" id="s${i+1}">${withTitle?`<h3>${s.t}</h3><div class="ms">${s.ms}</div>`:''}<div class="phone">${s.h}</div><ul>${s.li.map(x=>`<li>${x}</li>`).join('')}</ul></div>`;
}
document.addEventListener('DOMContentLoaded',()=>{
  const g=document.getElementById('grid');
  if(g) g.innerHTML=S.map((s,i)=>screenCard(s,i)).join('');
  document.querySelectorAll('[data-screen]').forEach(el=>{
    const i=parseInt(el.dataset.screen.replace('s',''),10)-1;
    if(S[i]) el.innerHTML=`<div class="phone">${S[i].h}</div>`;
  });
});
