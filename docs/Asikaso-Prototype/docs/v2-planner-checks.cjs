// Run from the project root: node docs/v2-planner-checks.cjs
// Tests the live prototype's parsing/planning code without a browser dependency.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');
const html = fs.readFileSync(path.join(__dirname, '..', 'V2.html'), 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
new vm.Script(script); // Parse the complete application, including the UI.
const core = script.slice(script.indexOf('const PLACES='), script.indexOf('/* ---------- navigation'));
const conversions = script.slice(script.indexOf('function templateToErrand('), script.indexOf('const tplApplied='));
const context = vm.createContext({assert, structuredClone});
vm.runInContext(core + '\n' + conversions + `
  const sample = ['Kuha data sa registrar, before 4pm','Capstone pitch 11-2 sa PLP','Sunduin si jowa sa Ortigas 3pm','Lunch with her after','Grocery for Mom pauwi, kung may time'];
  const errands=[];
  sample.forEach((text,i)=>errands.push({id:'e'+i,...interpret(text,errands)}));
  const options={from:'plp',to:'home',time:510,deadline:1080,mode:'motor',buffer:0};
  const plan=solve(errands,options);
  assert.equal(plan.homeArrive,1050,'Baseline day still arrives at 5:30 PM');
  assert.equal(plan.stops.length,5);
  const late=solve(errands,{...options,deadline:1020});
  assert.equal(late.dropped.length,1,'Only optional groceries are dropped');
  assert.equal(late.dropped[0].cat,'grocery');
  const examples=['Buy medicine','Go to gym','Buy flowers','Change oil'];
  const cats=['pharmacy','gym','florist','service'];
  examples.forEach((text,i)=>{const e=interpret(text,[]);assert.equal(e.cat,cats[i]);assert.equal(e.kind,'any');assert.equal(e.review,false);assert.ok(branchesOf(e.cat).length>=2)});
  const exampleErrands=examples.map((text,i)=>({id:'x'+i,...interpret(text,[])}));
  assert.equal(solve(exampleErrands,options).stops.length,4);
  const base={id:'rule',title:'Visit',kind:'specific',place:'plp',cat:'other',t1:null,t2:600,dur:60,must:true,after:null,last:false,review:false};
  const boundary={...options,from:'plp',to:'plp',time:600,deadline:720};
  assert.ok(evaluate([{...base,when:'arrive'}],{},boundary),'Arrive by 10 permits finishing at 11');
  assert.equal(evaluate([{...base,when:'before'}],{},boundary),null,'Finish before 10 rejects finishing at 11');
  assert.equal(evaluate([{...base,when:'arrive'}],{},{...boundary,time:601}),null,'Arrival after deadline is rejected');
  assert.equal(bestFor([...exampleErrands,{...base,when:'arrive',t2:509},...errands.slice(1,3)],options,{}),null,'Large search respects arrival deadlines before departure');
  const arrival=interpret('Gym arrive by 6pm',[]);assert.equal(arrival.when,'arrive');assert.equal(arrival.t2,1080);
  const edited={...base,kind:'any',cat:'gym',place:null,when:'arrive',after:'parent',last:true,must:false};
  const restored=templateToErrand(errandToTemplate(edited));
  assert.equal(restored.when,'arrive');assert.equal(restored.after,'parent');assert.equal(restored.last,true);assert.equal(restored.must,false);
  assert.equal(restored.t2,600);
  const pharmacy=templateToErrand(S.templates[1].items[2]);assert.equal(pharmacy.cat,'pharmacy');
`, context);
console.log('PASS: application syntax, original sample plan, optional drop, four example categories, arrival vs completion deadlines, large-plan constraints, and template rule preservation.');
