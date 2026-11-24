"use strict";
/* A deliberately non-executing, offline learning console.
   No external requests, browser storage, command execution or server mutations. */
(() => {
  const el = id => document.getElementById(id);
  const letters = ["A", "B", "C"];
  const state = { data: null, mission: 0, phase: 0, choices: new Map(), hints: new Set(), reflections: new Map() };
  const githubRoot = "https://github.com/Mishkaaass/terraform-aws-lab/blob/main/";
  const total = () => state.data.missions.reduce((n,m) => n + m.phases.length, 0);
  const key = (m,p) => m + ":" + p;
  const q = () => state.data.missions[state.mission];
  const phase = () => q().phases[state.phase];
  function node(tag,className,text) {
    const n=document.createElement(tag);
    if(className)n.className=className;
    if(text!==undefined)n.textContent=text;
    return n;
  }
  function wipe(parent) {parent.replaceChildren();}
  function button(text, className, onClick){
    const b=node("button",className,text); b.type="button";b.addEventListener("click",onClick); return b;
  }
  function score() {
    let correct=0;
    state.choices.forEach((ans,k)=>{
      const [m,p]=k.split(":").map(Number);
      if(state.data.missions[m]?.phases[p]?.answer===ans) correct++;
    });
    const done=state.choices.size;
    el("score").replaceChildren(document.createTextNode(String(correct).padStart(2,"0")));
    el("score").append(node("span","score-denom","/"+total()));
    el("progress-text").textContent=done+" of "+total()+" decisions attempted";
  }
  function complete(m) {return state.data.missions[m].phases.every((p,i)=>state.choices.has(key(m,i)));}
  function renderNav(){
    const nav=el("mission-nav");wipe(nav);
    state.data.missions.forEach((m,i)=>{
      const b=node("button","nav-item"+(i===state.mission?" active":""),"");
      b.type="button";b.setAttribute("aria-current",i===state.mission?"step":"false");
      b.append(node("span","nav-num",m.index));
      b.append(node("span","nav-label",m.title));
      if(complete(i))b.append(node("span","nav-check","✓"));
      b.addEventListener("click",()=>switchMission(i));
      nav.append(b);
    });
  }
  function switchMission(i){
    state.reflections.set(state.mission,el("reflection").value);
    state.mission=i;
    const firstUnanswered=state.data.missions[i].phases.findIndex((p,j)=>!state.choices.has(key(i,j)));
    state.phase=firstUnanswered<0?2:firstUnanswered;
    render();
    el("mission").scrollIntoView({behavior:"auto",block:"start"});
  }
  function renderEvidence(){
    const target=el("evidence");wipe(target);
    q().evidence.forEach(e=>{
      const wrap=node("div","terminal");
      wrap.append(node("div","terminal-title",e.label));
      const pre=node("pre","",e.body);
      wrap.append(pre);target.append(wrap);
    });
    const list=el("source-list");wipe(list);
    q().paths.forEach(path=>{
      const link=node("a","source-link");link.href=githubRoot+path;link.target="_blank";link.rel="noopener noreferrer";
      link.append(node("span","",path));link.append(node("small","","↗"));list.append(link);
    });
  }
  function select(answer) {
    const k=key(state.mission,state.phase);
    if(state.choices.has(k))return;
    state.choices.set(k,answer);
    renderQuestion();
    renderNav();score();
  }
  function renderQuestion(){
    const p=phase(),chosen=state.choices.get(key(state.mission,state.phase));
    const answered=chosen!==undefined, options=el("options"),feedback=el("feedback");
    el("challenge-stage").textContent="DECISION "+(state.phase+1)+" — "+p.stage;
    el("question").textContent=p.question;
    wipe(options);
    p.choices.forEach((label,i)=>{
      const b=button("","choice"+(answered?(i===p.answer?" correct":i===chosen?" incorrect":""):""),()=>select(i));
      b.disabled=answered;
      b.append(node("span","choice-letter",letters[i]));
      b.append(node("span","choice-text",label));
      options.append(b);
    });
    feedback.hidden=!answered;wipe(feedback);
    if(answered) {
      const correct=chosen===p.answer;
      feedback.className="feedback"+(correct?"":" bad");
      feedback.append(node("strong","",correct?"✓ Correct decision":"✕ Not the safest decision"));
      feedback.append(node("p","",p.why));
      feedback.append(node("div","proof-text","EVIDENCE → "+p.proof));
      const link=node("a","","Read source: "+p.source+" ↗");
      link.href=githubRoot+p.source;link.target="_blank";link.rel="noopener noreferrer";
      feedback.append(link);
      feedback.append(node("span","command-label","REPRODUCTION / INSPECTION REFERENCE"));
      feedback.append(node("pre","",p.command));
      const labels={readonly:"Read-only inspection (context required)",interactive:"Interactive access; no automatic execution","changes-emulator":"Changes only the running local emulator; review the runbook","guarded-cloud":"Cloud guard checks required; do not execute without separate approval"};
      feedback.append(node("div","command-caution",labels[p.safety]));
    }
    el("hint").textContent=p.hint;
    const opened=state.hints.has(key(state.mission,state.phase));
    el("hint").hidden=!opened;
    el("hint-btn").textContent=opened?"Hide thinking hint":"Show thinking hint";
    el("next-btn").disabled=!answered;
    el("next-btn").textContent=state.phase===2?"Review engineering debrief →":"Next decision →";
  }
  function render(){
    const m=q();
    el("scenario-index").textContent="INCIDENT "+m.index+" / "+String(state.data.missions.length).padStart(2,"0");
    el("scenario-type").textContent=m.level.toUpperCase();
    el("impact").textContent=m.impact.toUpperCase();
    el("track").textContent=m.track.toUpperCase();
    el("scenario-title").textContent=m.title;
    el("scenario-story").textContent=m.story;
    el("phase-number").textContent="0"+(state.phase+1)+" / 03";
    const steps=el("phase-steps");wipe(steps);
    for(let i=0;i<3;i++)steps.append(node("span","step"+(i<state.phase?" past":i===state.phase?" current":"")));
    renderEvidence();renderQuestion();
    el("debrief").hidden=true;el("challenge").hidden=false;
    el("reflection").value=state.reflections.get(state.mission)||"";
    el("copied").textContent="";
    el("next-mission").textContent=state.mission===state.data.missions.length-1?"Restart first mission →":"Next mission →";
    renderNav();score();
  }
  function next(){
    if(!state.choices.has(key(state.mission,state.phase)))return;
    if(state.phase<2){state.phase++;render();return;}
    el("challenge").hidden=true;el("debrief").hidden=false;
    el("debrief-text").textContent=q().debrief;
    el("reflection").focus();
  }
  function makeNotes(){
    const m=q(),lines=[
      "ENGINEERING REVIEW — "+m.title,
      "Scenario: "+m.story,
      "Source: https://github.com/Mishkaaass/terraform-aws-lab",
      "",
      ...m.phases.flatMap((p,i)=>{
        const answer=state.choices.get(key(state.mission,i));
        return ["DECISION "+(i+1)+": "+p.question,
          "My answer: "+(answer===undefined?"Not attempted":p.choices[answer]),
          "Outcome: "+(answer===undefined?"Not attempted":answer===p.answer?"Correct":"Needs review"),
          "Engineering rationale: "+p.why,
          "Proof: "+p.proof,
          "Source: "+p.source,""];
      }),
      "MY EXPLANATION:",
      el("reflection").value.trim()||"[Not written yet]",
      "",
      "Note: decisions are simulated and require independent runtime verification."
    ];
    return lines.join("\n");
  }
  async function copyNotes(){
    state.reflections.set(state.mission,el("reflection").value);
    const text=makeNotes();
    try{await navigator.clipboard.writeText(text);el("copied").textContent="Review notes copied.";}
    catch(e){
      const box=el("reflection");
      box.value=text;box.focus();box.select();
      el("copied").textContent="Clipboard unavailable. Notes are selected; copy manually.";
    }
  }
  function reset(){
    if(!window.confirm("Reset all answers and notes for this browser session? No infrastructure is affected."))return;
    state.choices.clear();state.hints.clear();state.reflections.clear();
    state.mission=0;state.phase=0;render();
  }
  function setupEvents(){
    el("hint-btn").addEventListener("click",()=>{
      const k=key(state.mission,state.phase);
      if(state.hints.has(k))state.hints.delete(k);else state.hints.add(k);
      renderQuestion();
    });
    el("next-btn").addEventListener("click",next);
    el("copy-notes").addEventListener("click",copyNotes);
    el("reset-all").addEventListener("click",reset);
    el("next-mission").addEventListener("click",()=>{
      state.reflections.set(state.mission,el("reflection").value);
      switchMission((state.mission+1)%state.data.missions.length);
    });
    el("reflection").addEventListener("input",()=>{
      state.reflections.set(state.mission,el("reflection").value);
    });
  }
  async function init(){
    try{
      const response=await fetch("./missions.json",{cache:"no-store"});
      if(!response.ok)throw new Error("HTTP "+response.status);
      const data=await response.json();
      if(data.schema!==1||!Array.isArray(data.missions)||data.missions.length<1)throw new Error("Unsupported mission format");
      for(const m of data.missions){
        if(!Array.isArray(m.phases)||m.phases.length!==3||!Array.isArray(m.evidence)||!Array.isArray(m.paths))throw new Error("Malformed mission: "+m.id);
        for(const p of m.phases)if(!Array.isArray(p.choices)||p.choices.length!==3||![0,1,2].includes(p.answer))throw new Error("Malformed challenge: "+m.id);
      }
      state.data=data;
      el("sim-disclosure").textContent="◈ SIMULATION BOUNDARY — "+data.disclosure;
      setupEvents();render();
    }catch(error){
      el("fatal").hidden=false;
      el("fatal").textContent="Could not load missions.json. Launch from the project root with: python3 -m http.server 8765 --bind 127.0.0.1 (then open /engineering-lab/). Details: "+error.message;
    }
  }
  init();
})();
