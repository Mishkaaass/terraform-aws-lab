"use strict";
/* Infrastructure Studio: non-executing browser experience; no privileged actions, no client-side persistence,
   no arbitrary HTML injection and no external network calls except source-link navigation. */
(() => {
  const $ = id => document.getElementById(id);
  const root = "https://github.com/Mishkaaass/terraform-aws-lab/blob/main/";
  const el = (tag, className, value) => {
    const x = document.createElement(tag);
    if(className)x.className=className;
    if(value!==undefined)x.textContent=value;
    return x;
  };
  const clear = x => x.replaceChildren();
  const click = (text, className, onClick) => {
    const b=el("button",className,text);b.type="button";b.addEventListener("click",onClick);return b;
  };
  async function copy(text,target) {
    try { await navigator.clipboard.writeText(text);if(target)target.textContent="COPIED TO CLIPBOARD";}
    catch(e) { if(target)target.textContent="CLIPBOARD BLOCKED; SELECT AND COPY THE TEXT MANUALLY"; }
  }
  const st={
    tab:"map",node:"vpc",
    config:{compute:false,ssm:false,nat:false,public:false,ssh:false},
    steps:new Map(),step:0,preset:null,
    missions:null,mission:0,phase:0,choices:new Map(),hints:new Set(),reflections:new Map()
  };

  /* Architecture grounded in modules/network/main.tf, security, identity and compute.
     The optional endpoints/NAT/SSH behavior is explicitly hypothetical. */
  const components={
    vpc:{name:"Terraform-managed VPC",kind:"NETWORK FOUNDATION",desc:"The shared network boundary used by the local Floci provider and the optional real AWS root.",rows:[["CIDR","10.42.0.0/16"],["DNS","Enabled"],["Availability Zones","2"],["Subnets","4"]],why:"A VPC is a network boundary, not an internet access policy. Subnet routing, security groups and endpoints still determine reachability.",source:"modules/network/main.tf"},
    igw:{name:"Internet Gateway",kind:"PUBLIC CONNECTIVITY",desc:"Attached to the VPC. Only the public route table sends 0.0.0.0/0 traffic through it.",rows:[["Internet route","Public subnet only"],["Default route","0.0.0.0/0"],["Private subnet route","Absent"]],why:"An IGW attached to a VPC does not automatically make every subnet public. Follow route-table associations.",source:"modules/network/main.tf"},
    public1:{name:"Public subnet · AZ a",kind:"SUBNET / ROUTING",desc:"10.42.0.0/24. Has a route to the Internet Gateway, but instances do not automatically get public IPs.",rows:[["CIDR","10.42.0.0/24"],["AZ","us-east-1a (Floci)"],["Public IP auto-assign","Disabled"]],why:"'Public' is about routing. A resource still needs an address and appropriate security controls for public accessibility.",source:"modules/network/main.tf"},
    public2:{name:"Public subnet · AZ b",kind:"SUBNET / ROUTING",desc:"10.42.1.0/24. Second AZ provides a separate placement boundary; it does not by itself prove high availability.",rows:[["CIDR","10.42.1.0/24"],["AZ","us-east-1b (Floci)"],["Default route","Internet Gateway"]],why:"Multiple AZs improve placement options. Availability also depends on replicas, dependencies and load balancing.",source:"modules/network/main.tf"},
    private1:{name:"Isolated private subnet · AZ a",kind:"SUBNET / ISOLATION",desc:"10.42.10.0/24. The associated private route table has only the implicit VPC local route.",rows:[["CIDR","10.42.10.0/24"],["Internet egress","None by default"],["NAT gateway","Not provisioned"]],why:"The design intentionally cannot reach the public internet from the private subnet without additional routes and policies.",source:"modules/network/main.tf"},
    private2:{name:"Isolated private subnet · AZ b",kind:"SUBNET / ISOLATION",desc:"10.42.11.0/24. Same isolation as AZ a, independent subnet association.",rows:[["CIDR","10.42.11.0/24"],["Default route","None"],["SSM endpoints","Not provisioned"]],why:"The subnet name does not enforce isolation; the route table and security/network policies do.",source:"modules/network/main.tf"},
    sg:{name:"Instance security group",kind:"NETWORK PERMISSIONS",desc:"No ingress rules. The only configured outbound rule is TCP 443 to the VPC CIDR.",rows:[["Ingress","No rules"],["Egress","TCP 443 only"],["Destination","VPC CIDR"],["Public SSH","Not allowed"]],why:"This is a deliberate restrictive baseline. Adding a NAT gateway alone would not allow public HTTPS because the egress rule remains VPC-scoped.",source:"modules/security/main.tf"},
    iam:{name:"Instance IAM profile",kind:"IDENTITY & AUTHORIZATION",desc:"An EC2 role and instance profile attached to the managed SSM core agent policy, not AdministratorAccess.",rows:[["Role","EC2 trust"],["Policy","AmazonSSMManagedInstanceCore"],["Public credentials","None"]],why:"A valid IAM identity authorizes actions but does not magically create reachability to SSM service endpoints.",source:"modules/identity/main.tf"},
    ec2:{name:"Optional private EC2",kind:"COMPUTE / DISABLED BY DEFAULT",desc:"An optional t3.micro defined in Terraform but disabled in the default Floci and AWS deployments.",rows:[["Default count","0"],["Public IP","false"],["IMDS","v2 required"],["Volume","Encrypted gp3"]],why:"EC2 is a configuration exercise until explicitly enabled. The local Floci demo intentionally avoids mounting the Docker socket needed for EC2 execution.",source:"modules/compute/main.tf"}
  };

  function svgNode(tag,attrs,text) {
    const n=document.createElementNS("http://www.w3.org/2000/svg",tag);
    for(const [k,v] of Object.entries(attrs||{}))n.setAttribute(k,String(v));
    if(text!==undefined)n.textContent=text;
    return n;
  }
  function line(svg,x1,y1,x2,y2,type="") {
    const p=svgNode("path",{d:`M${x1} ${y1} L${x2} ${y2}`,class:"map-wire "+type});
    svg.append(p);
  }
  function label(svg,x,y,t,cls="map-tiny") {svg.append(svgNode("text",{x,y,class:cls},t));}
  function rect(svg,x,y,w,h,stroke,dash) {
    const r=svgNode("rect",{x,y,width:w,height:h,rx:9,fill:"none",stroke:stroke||"#cad9cc","stroke-width":1.5});
    if(dash)r.setAttribute("stroke-dasharray","7 6");
    svg.append(r);
  }
  function boxNode(svg,id,x,y,w,h,name,sub,optional=false) {
    const g=svgNode("g",{class:"map-node"+(optional?" optional":"")+(st.node===id?" selected":""),tabindex:"0",role:"button","aria-label":"Inspect "+name});
    g.append(svgNode("rect",{x,y,width:w,height:h}));
    g.append(svgNode("text",{x:x+13,y:y+25,class:"map-label"},name));
    g.append(svgNode("text",{x:x+13,y:y+44,class:"map-sub"},sub));
    g.addEventListener("click",()=>chooseNode(id));
    g.addEventListener("keydown",e=>{if(e.key==="Enter"||e.key===" "){e.preventDefault();chooseNode(id)}});
    svg.append(g);
  }
  function chooseNode(id){st.node=id;renderTopology();renderInspector();}
  function renderTopology(){
    const svg=$("topology");clear(svg);
    rect(svg,25,54,821,423,"#849d8d");
    label(svg,45,45,"TERRAFORM-MANAGED · VPC 10.42.0.0/16","map-label");
    label(svg,660,45,"LOCAL FLOCI DESIGN","map-tiny");
    rect(svg,65,180,375,245,"#b5c9b8");
    rect(svg,461,180,342,245,"#b5c9b8");
    label(svg,80,170,"AVAILABILITY ZONE A");
    label(svg,475,170,"AVAILABILITY ZONE B");
    // Routed links are schematic, not measured path traces.
    // Only the public route table has an IGW default route.
    // Draw NO lines from the gateway to private subnets: that would mislead learners.
    line(svg,222,113,222,194,"public");
    line(svg,222,113,608,194,"public");
    label(svg,104,307,"PRIVATE NETWORK · NO INTERNET ROUTE");
    label(svg,498,307,"PRIVATE NETWORK · NO INTERNET ROUTE");
    boxNode(svg,"vpc",335,8,200,63,"VPC / 10.42.0.0/16","Click to inspect");
    boxNode(svg,"igw",106,70,208,58,"INTERNET GATEWAY","Public routing");
    boxNode(svg,"iam",597,70,207,58,"IAM / SSM ROLE","Identity only");
    boxNode(svg,"public1",95,214,280,62,"PUBLIC · 10.42.0.0/24","IGW route · no auto public IP");
    boxNode(svg,"public2",490,214,280,62,"PUBLIC · 10.42.1.0/24","IGW route · no auto public IP");
    boxNode(svg,"private1",95,328,280,62,"PRIVATE · 10.42.10.0/24","Local route only");
    boxNode(svg,"private2",490,328,280,62,"PRIVATE · 10.42.11.0/24","Local route only");
    boxNode(svg,"sg",75,443,240,57,"INSTANCE SECURITY GROUP","No ingress · VPC HTTPS");
    boxNode(svg,"ec2",535,443,265,57,"OPTIONAL PRIVATE EC2","count = 0 (default)",true);
  }
  function renderInspector(){
    const v=components[st.node];
    $("inspector-kind").textContent=v.kind;
    $("inspector-name").textContent=v.name;
    $("inspector-desc").textContent=v.desc;
    $("inspector-why").textContent=v.why;
    const p=$("inspector-details");clear(p);
    v.rows.forEach(([k,val])=>{const row=el("div","detail-row");row.append(el("span","",k),el("strong","",val));p.append(row)});
    $("inspector-source").href=root+v.source;
  }

  const scenarios={
    isolated:{config:{compute:true,ssm:false,nat:false,public:false,ssh:false},lesson:"A private EC2 needs BOTH an IAM role and connectivity to SSM services. The role only authorizes requests; there are no SSM endpoints or NAT in the current repo."},
    endpoints:{config:{compute:true,ssm:true,nat:false,public:false,ssh:false},lesson:"Private interface endpoints could create a management path. They have NOT been implemented: endpoint security groups, DNS, supported APIs and actual connectivity still require design and testing."},
    exposed:{config:{compute:true,ssm:false,nat:false,public:true,ssh:true},lesson:"Public IPv4 and SSH from everywhere violate the zero-ingress, private-only design. An instance is not made safely manageable simply by making it publicly reachable."}
  };
  function selectPreset(name){
    const example=scenarios[name];if(!example)return;
    st.preset=name;st.config={...example.config};renderDesign();
  }
  function renderDesign(){
    for(const k of Object.keys(st.config))$("cfg-"+k).checked=st.config[k];
    document.querySelectorAll("[data-preset]").forEach(button=>{
      const on=button.dataset.preset===st.preset;
      button.classList.toggle("selected",on);
      button.setAttribute("aria-pressed",String(on));
    });
    $("design-lesson").textContent=st.preset?scenarios[st.preset].lesson:
      "Choose Example 1 to begin. Then compare it with Example 2, or change the switches yourself.";
    const c=st.config,changes=[],issues=[];
    if(c.compute)changes.push(["+","module.compute.aws_instance.this[0] (preview only; Floci EC2 execution disabled)"]);
    if(c.ssm)changes.push(["+","Proposed SSM, SSMMessages and EC2Messages interface endpoints with SG/DNS (not implemented)"]);
    if(c.nat)changes.push(["+","Proposed NAT + private route table default route (not implemented)"]);
    if(c.public)changes.push(["~","Hypothetical public IP assignment (not implemented; conflicts with current compute module)"]);
    if(c.ssh)changes.push(["+","Hypothetical SSH ingress 0.0.0.0/0 (not implemented; violates default SG)"]);
    const dangerous=c.public||c.ssh;
    if(c.compute&&!c.ssm)issues.push({level:"warn",title:"SSM role is not a network route",body:"The private instance has an IAM role but cannot reach SSM service endpoints without a viable route. Current VPC has neither NAT nor SSM endpoints."});
    if(c.ssm&&!c.compute)issues.push({level:"normal",title:"Endpoints with no guest",body:"Adding interfaces would be a separate design task. There is currently no EC2 instance to manage."});
    if(c.ssm&&c.compute)issues.push({level:"normal",title:"Private management path proposed",body:"SSM would also require correct endpoint DNS, endpoint security-group rules, IAM and real connectivity tests. The diagram alone cannot prove a working session."});
    if(c.nat)issues.push({level:"warn",title:"A NAT route does not override the instance SG",body:"Current egress is restricted to TCP 443 within the VPC CIDR. Public HTTPS remains blocked without another explicit SG policy change."});
    if(c.public)issues.push({level:"critical",title:"Public address violates the repo's private compute constraint",body:"A public IP is neither needed nor authorized by this architecture; it does not fix the lack of private SSM connectivity."});
    if(c.ssh)issues.push({level:"critical",title:"Inbound SSH from the world",body:"A 0.0.0.0/0 inbound rule expands attack surface and contradicts the no-ingress security-group design."});
    if(!changes.length)issues.push({level:"normal",title:"Baseline isolation",body:"Two isolated private subnets, zero ingress, no NAT, no EC2. Validate these assumptions with source and mock tests."});
    $("plan-count").textContent=changes.length+" HYPOTHETICAL CHANGE"+(changes.length===1?"":"S");
    const verdict=$("plan-verdict");verdict.className="verdict"+(dangerous?" bad":issues.some(i=>i.level==="warn")?" warn":"");
    clear(verdict);
    verdict.append(el("strong","",dangerous?"REJECT AS DESIGNED":changes.length?"NEEDS ENGINEERING REVIEW":"BASELINE / NO CHANGE"));
    verdict.append(el("p","",dangerous?"This proposal introduces unnecessary public exposure. Neither this browser nor the repository has applied it.":changes.length?"This is a learning-model preview, not Terraform plan output. Reproduce the supported case with local commands before asserting success.":"The design sandbox matches the repository's default configuration."));
    const list=$("plan-changes");clear(list);
    if(!changes.length)list.append(el("div","plan-item","No differences proposed."));
    for(const [mark,desc] of changes){const x=el("div","plan-item");x.append(el("b","",mark),el("span","",desc));list.append(x);}
    const warnings=$("plan-analysis");clear(warnings);
    issues.forEach(i=>{const x=el("div","analysis-item"+(i.level==="critical"?" critical":""));x.append(el("strong","",i.title),el("p","",i.body));warnings.append(x)});
    const lines=["EDUCATIONAL DESIGN LABELS — NOT TERMINAL COMMANDS","Private EC2 instance: "+(c.compute?"proposed ON":"OFF by default"),"Private SSM endpoints: "+(c.ssm?"proposed; not built":"not present"),"NAT gateway: "+(c.nat?"proposed; not built":"not present"),"Public instance IP: "+(c.public?"hypothetical; violates baseline":"disabled"),"Inbound SSH from the internet: "+(c.ssh?"hypothetical; insecure":"blocked"),"These switches never modify the Terraform files or Floci."];
    $("plan-code").textContent=lines.join("\n");
  }

  /* Independently executed steps. Evidence checks inspect supplied text only;
     they are not attestation and never mark a command as executed on their own. */
  const steps=[
    {id:"tests",purpose:"Check Terraform's configuration assertions before introducing any services.",impact:"May initialize/download local provider files; no Docker or AWS deployment.",expected:"Terraform test prints Success and a number of passed tests.",title:"Prove configuration intent",risk:"READ-ONLY · NO DOCKER",desc:"Mock provider tests check network, IAM and security assumptions without hitting an AWS endpoint. They don't show real routing.",command:"make test",hint:"Check for 'Success!' and 'passed' in Terraform test output.",test:t=>/Success!/.test(t)&&/passed/i.test(t),proof:"A green mock test proves HCL assertions, not the AWS control plane."},
    {id:"boot",purpose:"Start a local implementation of selected AWS APIs. It isn't the real AWS cloud.",impact:"Starts or reuses a Docker container listening on 127.0.0.1:4566.",expected:"The terminal confirms Floci API responding on 127.0.0.1:4566.",title:"Start a local control plane",risk:"STARTS LOCAL CONTAINER",desc:"Boot the Floci emulator on localhost:4566, without the Docker socket. This is a local API service, not real AWS.",command:"make local-up",hint:"Look for the local health response confirmation.",test:t=>/Floci API responding on 127\.0\.0\.1:4566/.test(t),proof:"The emulator answers, but Terraform resources may not exist yet."},
    {id:"plan",purpose:"Inspect what Terraform WOULD add, change or destroy before approving anything.",impact:"Does not apply resources, but make may start Floci and Terraform can refresh local state.",expected:"You see resource counts or a No changes statement; examine the entire plan.",title:"Predict the Terraform diff",risk:"READ-ONLY PLAN",desc:"Terraform compares desired configuration against local Floci state. Read every proposed resource before applying.",command:"make local-plan",hint:"Inspect 'Plan: X to add, Y to change, Z to destroy' or a no-change result.",test:t=>/Plan:\s*\d+ to add,\s*\d+ to change,\s*\d+ to destroy\b/.test(t)||/No changes\. Your infrastructure matches/.test(t),proof:"A plan describes intent. It is not evidence of actual resources."},
    {id:"apply",purpose:"Create the planned VPC, subnets and IAM in the LOCAL emulator.",impact:"Modifies Floci resources and local Terraform state; Terraform requests terminal confirmation.",expected:"Apply complete appears with resource counts you can independently inspect.",title:"Build the emulated infrastructure",risk:"CHANGES EMULATOR · CONFIRM",desc:"Apply only after reviewing the plan. Terraform asks for confirmation, then creates the VPC/subnets/routes/IAM/SG in Floci.",command:"make local-apply",hint:"Require 'Apply complete!' followed by the managed resource counts.",test:t=>/Apply complete! Resources: \d+ added, \d+ changed, \d+ destroyed\./.test(t),proof:"The apply affects the emulator and local Terraform state, not a real AWS account."},
    {id:"verify",purpose:"Independently query the emulator's resources rather than relying on the apply summary.",impact:"Local AWS CLI read requests only; they target 127.0.0.1:4566.",expected:"Query confirms VPC/subnets/security group. Examine the returned values.",title:"Inspect the control plane independently",risk:"LOCAL EMULATOR · READ",desc:"Query the emulator through AWS CLI. Observe VPC CIDR, subnet placement and security-group ingress rules.",command:"make local-verify",hint:"Look for '[OK] Queried emulated VPC, subnets, and SG via AWS CLI.'",test:t=>/\[OK\] Queried emulated VPC, subnets, and SG via AWS CLI\./.test(t),proof:"An independent API query strengthens evidence beyond Terraform's own output."},
    {id:"drift",purpose:"Observe an out-of-band VPC tag change, then identify and repair only that change.",impact:"Changes a local emulator tag; asks confirmation before applying a guarded repair. An interruption can leave drift.",expected:"PASS reports a narrow fix and a no-change Terraform plan.",title:"Simulate and repair drift",risk:"CHANGES EMULATOR TAG · CONFIRM",desc:"One script changes the local VPC Name tag out of band, requires a narrowly scoped saved plan, asks consent, repairs and verifies zero drift. Inspect it before running.",command:"make local-drift",hint:"Require '[PASS] Drift detected, safety-checked, repaired, and verified: No changes.'",test:t=>/\[PASS\] Drift detected, safety-checked, repaired, and verified: No changes\./.test(t),proof:"The drift script checks a single allowed VPC Name attribute change. It does not modify the real AWS environment."},
    {id:"guest",purpose:"Optionally inspect a real local Ubuntu KVM VM and its health API.",impact:"Read-only checks for Floci, libvirt and guest HTTP. No SSH or sudo.",expected:"Small JSON with UP/RUNNING/HEALTHY or unknown/unavailable if not present.",title:"Inspect your real Ubuntu VM (optional)",risk:"READ-ONLY · REQUIRES KVM",desc:"Run the local probe for boot state, DHCP lease, guest health and emulator status. Its output contains only fixed categorical fields.",command:"python3 engineering-lab/probe.py",hint:"Paste JSON from the probe, then use 'Inspect evidence' to see categories.",test:t=>{try{const o=JSON.parse(t.trim());return validProbe(o);}catch(e){return false}},proof:"The probe uses only read-only host observations. It doesn't SSH, alter Terraform state or authenticate to AWS."}
  ];
  const validProbe=o=>o&&o.schema===1&&o.source==="local-readonly-probe"&&typeof o.observed_at==="string"&&["up","down","unknown"].includes(o.floci)&&["running","stopped","absent","unknown"].includes(o.vm)&&["healthy","unavailable","unknown"].includes(o.health)&&typeof o.vm_ip==="string"&&o.vm_ip.length<=45&&/^([0-9]{1,3}\.){3}[0-9]{1,3}$|^$/.test(o.vm_ip)&&Object.keys(o).every(k=>["schema","source","observed_at","floci","vm","health","vm_ip"].includes(k));
  function renderSteps(){
    const nav=$("checkpoint-nav");clear(nav);
    steps.forEach((s,i)=>{const b=click("","checkpoint"+(i===st.step?" active":"")+(st.steps.has(i)?" done":""),()=>{st.step=i;renderSteps()});
      b.append(el("span","",st.steps.has(i)?"✓":String(i+1).padStart(2,"0")),document.createTextNode(s.id.toUpperCase()));nav.append(b);
    });
    $("checkpoint-progress").textContent=progressCount()+" / "+steps.length+" OUTPUTS VALIDATED";
    const s=steps[st.step];
    $("step-number").textContent="CHECKPOINT "+String(st.step+1).padStart(2,"0")+" / "+steps.length;
    $("step-risk").textContent=s.risk;
    $("step-title").textContent=s.title;
    $("step-explain").textContent=s.desc;
    $("step-purpose").textContent=s.purpose;
    $("step-impact").textContent=s.impact;
    $("step-expected").textContent=s.expected;
    $("step-command").textContent=s.command;
    $("step-proof").textContent="WHAT THIS PROVES → "+s.proof;
    $("step-output").value=st.steps.get("draft-"+st.step)||"";
    $("step-result").textContent=st.steps.has(st.step)?"Earlier pasted output contained the expected marker.":"";
    $("step-result").className=st.steps.has(st.step)?"pass":"";
  }
  function verifyStep(){
    const t=$("step-output").value.slice(0,20000);st.steps.set("draft-"+st.step,t);
    // Only completed numeric keys count; draft entries are not evidence.
    if(steps[st.step].test(t)) {
      st.steps.set(st.step,true);
      $("step-result").textContent="Expected text found. Review the entire output yourself before continuing.";
      $("step-result").className="pass";
    } else {
      st.steps.delete(st.step);
      $("step-result").textContent="NOT VERIFIED · "+steps[st.step].hint;
      $("step-result").className="";
    }
    // Preserve the user's pasted output and immediate feedback.
    renderStepIndicator();
    [...$("checkpoint-nav").children].forEach((button,i)=>{
      button.classList.toggle("done",st.steps.has(i));
      const label=button.querySelector("span");
      if(label)label.textContent=st.steps.has(i)?"✓":String(i+1).padStart(2,"0");
    });
  }
  function progressCount(){return [...st.steps.keys()].filter(Number.isInteger).length;}
  function renderEvidence(o){
    $("signal-floci").textContent=o.floci.toUpperCase();
    $("signal-kvm").textContent=o.vm.toUpperCase()+(o.vm_ip?" · "+o.vm_ip:"");
    $("signal-health").textContent=o.health.toUpperCase();
    $("signal-at").textContent=o.observed_at.slice(0,30);
    for(const [id,val] of [["signal-floci",o.floci],["signal-kvm",o.vm],["signal-health",o.health]]){
      $(""+id).className=(["up","running","healthy"].includes(val)?"ok":val==="unknown"?"":"warn");
    }
  }
  function inspectProbe(){
    const text=$("probe-input").value.trim();
    if(text.length>4096){$("probe-message").textContent="PROBE TOO LARGE; ACCEPTS FIXED SCHEMA ONLY";return;}
    try{
      const value=JSON.parse(text);
      if(!validProbe(value))throw new Error("Unexpected schema or status.");
      renderEvidence(value);
      $("probe-message").textContent="SCHEMA ACCEPTED · THESE ARE USER-SUPPLIED OBSERVATIONS";
    }catch(e){$("probe-message").textContent="REJECTED · EXPECTED JSON FROM python3 engineering-lab/probe.py";}
  }
  function renderStepIndicator(){const n=progressCount();$("checkpoint-progress").textContent=n+" / "+steps.length+" OUTPUTS VALIDATED";}
  function tab(name){
    if(!["map","design","real","cases"].includes(name))return;
    st.tab=name;
    document.querySelectorAll(".tab").forEach(b=>{const on=b.dataset.tab===name;b.classList.toggle("active",on);b.setAttribute("aria-selected",String(on));b.tabIndex=on?0:-1});
    document.querySelectorAll(".workview").forEach(p=>{p.hidden=p.id!=="view-"+name});
    if(name==="map"){renderTopology();renderInspector()}
    if(name==="design")renderDesign();
    if(name==="real"){renderSteps();renderStepIndicator()}
    if(name==="cases"&&st.missions)renderCase();
  }

  /* Preserve the original seven source-grounded incident cases. */
  const letters=["A","B","C"];
  const totalQuestions=()=>st.missions.missions.reduce((n,m)=>n+m.phases.length,0);
  const caseKey=(m,p)=>m+":"+p;
  const mission=()=>st.missions.missions[st.mission];
  const phase=()=>mission().phases[st.phase];
  function score(){
    let correct=0;
    st.choices.forEach((ans,key)=>{const [m,p]=key.split(":").map(Number);if(st.missions.missions[m]?.phases[p]?.answer===ans)correct++});
    $("score").replaceChildren(document.createTextNode(String(correct).padStart(2,"0")),el("span","score-denom","/"+totalQuestions()));
    $("progress-text").textContent=st.choices.size+" / "+totalQuestions()+" ATTEMPTED";
  }
  const completed=m=>st.missions.missions[m].phases.every((p,i)=>st.choices.has(caseKey(m,i)));
  function navCases(){
    const area=$("mission-nav");clear(area);
    st.missions.missions.forEach((m,i)=>{const b=click("","nav-item"+(i===st.mission?" active":""),()=>switchCase(i));b.setAttribute("aria-current",i===st.mission?"step":"false");b.append(el("span","nav-num",m.index),el("span","nav-label",m.title));if(completed(i))b.append(el("span","nav-check","✓"));area.append(b)});
  }
  function switchCase(i){
    st.reflections.set(st.mission,$("reflection").value);
    st.mission=i;const first=mission().phases.findIndex((p,j)=>!st.choices.has(caseKey(i,j)));st.phase=first<0?2:first;
    renderCase();
  }
  function evidenceCases(){
    const m=mission(),area=$("evidence");clear(area);
    m.evidence.forEach(e=>{const wrap=el("div","terminal");wrap.append(el("div","terminal-title",e.label),el("pre","",e.body));area.append(wrap)});
    const links=$("source-list");clear(links);
    m.paths.forEach(path=>{const a=el("a","source-link",path+" ↗");a.href=root+path;a.rel="noopener noreferrer";a.target="_blank";links.append(a)});
  }
  function chooseAnswer(index){
    const k=caseKey(st.mission,st.phase);if(st.choices.has(k))return;st.choices.set(k,index);renderQuestion();navCases();score();
  }
  function renderQuestion(){
    const p=phase(),selected=st.choices.get(caseKey(st.mission,st.phase)),answered=selected!==undefined;
    $("challenge-stage").textContent="DECISION "+(st.phase+1)+" / "+p.stage;
    $("question").textContent=p.question;
    const area=$("options");clear(area);
    p.choices.forEach((name,i)=>{const b=click("","choice"+(answered?(i===p.answer?" correct":i===selected?" incorrect":""):""),()=>chooseAnswer(i));b.disabled=answered;b.append(el("span","choice-letter",letters[i]),el("span","choice-text",name));area.append(b)});
    const feedback=$("feedback");feedback.hidden=!answered;clear(feedback);
    if(answered){const correct=selected===p.answer;feedback.className="answer-feedback"+(correct?"":" bad");
      feedback.append(el("strong","",correct?"✓ Supported decision":"✕ Revisit the evidence"),el("p","",p.why),el("div","proof-text","PROOF → "+p.proof));
      const a=el("a","","Open source: "+p.source+" ↗");a.href=root+p.source;a.rel="noopener noreferrer";a.target="_blank";feedback.append(a);
      feedback.append(el("span","command-label","INSPECTION REFERENCE (NEVER AUTO-EXECUTED)"),el("pre","",p.command));
      const policies={readonly:"Read-only inspection",interactive:"Requires local shell access","changes-emulator":"Changes the local emulator only; explicit approval","guarded-cloud":"Never execute outside a dedicated, guarded AWS sandbox"};
      feedback.append(el("div","command-caution",policies[p.safety]));
    }
    $("hint").textContent=p.hint;const on=st.hints.has(caseKey(st.mission,st.phase));$("hint").hidden=!on;
    $("hint-btn").textContent=on?"HIDE HINT":"SHOW HINT";
    $("next-btn").disabled=!answered;$("next-btn").textContent=st.phase===2?"OPEN POSTMORTEM →":"NEXT DECISION →";
  }
  function renderCase(){
    const m=mission();
    $("scenario-index").textContent="CASE "+m.index+" / "+String(st.missions.missions.length).padStart(2,"0");
    $("scenario-type").textContent=m.level.toUpperCase();$("impact").textContent=m.impact.toUpperCase();
    $("track").textContent=m.track.toUpperCase();$("scenario-title").textContent=m.title;$("scenario-story").textContent=m.story;
    $("phase-number").textContent="0"+(st.phase+1)+" / 03";
    const ind=$("phase-steps");clear(ind);for(let i=0;i<3;i++)ind.append(el("span","step"+(i<st.phase?" past":i===st.phase?" current":"")));
    evidenceCases();renderQuestion();$("debrief").hidden=true;$("challenge").hidden=false;
    $("reflection").value=st.reflections.get(st.mission)||"";$("copied").textContent="";
    $("next-mission").textContent=st.mission===st.missions.missions.length-1?"RESTART FIRST CASE →":"NEXT CASE →";
    navCases();score();
  }
  function nextQuestion(){
    if(!st.choices.has(caseKey(st.mission,st.phase)))return;
    if(st.phase<2){st.phase++;renderCase();return;}
    $("challenge").hidden=true;$("debrief").hidden=false;$("debrief-text").textContent=mission().debrief;$("reflection").focus();
  }
  function notes(){
    const m=mission(),out=["ENGINEERING POSTMORTEM — "+m.title,"SOURCE: "+root,""];
    m.phases.forEach((p,i)=>{const ans=st.choices.get(caseKey(st.mission,i));out.push("DECISION "+(i+1)+": "+p.question,"ANSWER: "+(ans===undefined?"Not attempted":p.choices[ans]),"RATIONALE: "+p.why,"EVIDENCE: "+p.proof,"SOURCE: "+p.source,"")});
    out.push("MY INDEPENDENT EXPLANATION:",$("reflection").value.trim()||"[not written]","Simulation does not establish real cloud or host runtime behavior.");
    return out.join("\n");
  }
  async function init(){
    try{
      const r=await fetch("./missions.json",{cache:"no-store"});if(!r.ok)throw Error("HTTP "+r.status);
      const data=await r.json();if(data.schema!==1||!Array.isArray(data.missions)||data.missions.length<7)throw Error("Unexpected mission schema");
      for(const m of data.missions)if(m.phases.length!==3||m.phases.some(p=>p.choices.length!==3||![0,1,2].includes(p.answer)))throw Error("Invalid decision data");
      st.missions=data;
      document.querySelectorAll(".tab").forEach(b=>b.addEventListener("click",()=>tab(b.dataset.tab)));
      document.querySelectorAll("[data-go]").forEach(b=>b.addEventListener("click",()=>{
        tab(b.dataset.go);
        document.querySelector(".tabs").scrollIntoView({block:"start",behavior:"smooth"});
      }));
      document.querySelectorAll("[data-preset]").forEach(b=>b.addEventListener("click",()=>selectPreset(b.dataset.preset)));
      document.querySelectorAll(".switch-row input").forEach(b=>b.addEventListener("change",()=>{
        st.config[b.id.slice(4)]=b.checked;st.preset=null;renderDesign();
      }));
      $("design-reset").addEventListener("click",()=>{Object.keys(st.config).forEach(k=>st.config[k]=false);st.preset=null;renderDesign()});
      $("copy-decision").addEventListener("click",()=>copy("INFRASTRUCTURE STUDIO DESIGN REVIEW\n"+$("plan-code").textContent+"\nReview: "+$("decision-note").value,$("decision-copy-status")));
      $("copy-command").addEventListener("click",()=>copy(steps[st.step].command,$("step-result")));
      $("copy-probe").addEventListener("click",()=>copy($("probe-command").textContent,$("probe-message")));
      $("copy-doctor").addEventListener("click",()=>copy("bash engineering-lab/doctor.sh",$("step-result")));
      $("step-output").addEventListener("input",()=>st.steps.set("draft-"+st.step,$("step-output").value.slice(0,20000)));
      $("verify-step").addEventListener("click",verifyStep);
      $("next-checkpoint").addEventListener("click",()=>{st.step=(st.step+1)%steps.length;renderSteps();});
      $("inspect-probe").addEventListener("click",inspectProbe);
      $("hint-btn").addEventListener("click",()=>{const k=caseKey(st.mission,st.phase);st.hints.has(k)?st.hints.delete(k):st.hints.add(k);renderQuestion()});
      $("next-btn").addEventListener("click",nextQuestion);
      $("next-mission").addEventListener("click",()=>switchCase((st.mission+1)%st.missions.missions.length));
      $("copy-notes").addEventListener("click",()=>copy(notes(),$("copied")));
      $("reflection").addEventListener("input",()=>st.reflections.set(st.mission,$("reflection").value));
      tab("map");renderDesign();renderSteps();renderCase();
    }catch(err){$("fatal").hidden=false;$("fatal").textContent="Could not load the interactive lab. Start from the repository root with: python3 engineering-lab/serve.py — "+err.message;}
  }
  init();
})();
