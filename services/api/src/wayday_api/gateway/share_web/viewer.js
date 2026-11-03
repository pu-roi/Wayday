/* Credentials remain in memory and the URL fragment, never storage or requests' URLs. */
const el = id => document.getElementById(id);
const parsed = /^([a-f0-9-]{36})\.([A-Za-z0-9_-]{43})$/.exec(location.hash.slice(1));
let map, routeBounds, overlays = [], liveMarker, expiry = 0, current, poll, expiryTimer, loading = false;
let mapAttempted = false;
const coordinate = p => ({lat:p.latitude,lng:p.longitude});
function clearLocation(){ if(liveMarker)liveMarker.setMap(null);liveMarker=null; }
function unavailable(){clearInterval(poll);clearTimeout(expiryTimer);clearLocation();el('trip').hidden=true;el('stops').replaceChildren();el('unavailable').hidden=false;el('status').textContent='Sharing is unavailable.';current=null;overlays.forEach(o=>o.setMap(null));overlays=[];}
function marker(point,label,locationMarker=false){
  class WaydayMarker extends google.maps.OverlayView{
    onAdd(){this.node=document.createElement('div');this.node.className='map-marker'+(locationMarker?' location':'');this.node.textContent=label;this.node.setAttribute('aria-label',locationMarker?'Sender location':'Stop '+label);this.getPanes().overlayMouseTarget.append(this.node);}
    draw(){const p=this.getProjection().fromLatLngToDivPixel(new google.maps.LatLng(point));this.node.style.left=p.x+'px';this.node.style.top=p.y+'px';}
    onRemove(){this.node?.remove();}
  }
  const overlay=new WaydayMarker();overlay.setMap(map);return overlay;
}
function updateLocation(){
  clearLocation();if(!current||document.hidden)return;
  const fix=current.ownerLocation;
  const fresh=fix&&Date.now()/1000-fix.recordedAt<=45&&Date.now()/1000-fix.receivedAt<=45;
  if(fresh){if(map)liveMarker=marker(coordinate(fix),'',true);el('location-status').textContent=(fix.accuracy>100?'Approximate location':'Live location')+' · updated '+Math.max(0,Math.floor(Date.now()/1000-fix.recordedAt))+'s ago';}
  else el('location-status').textContent=current.ownerSharing?'Waiting for a fresh location.':'Live location is off.';
}
function render(data){
  current=data;expiry=data.expiresAt*1000;if(expiry<=Date.now())return unavailable();
  const plan=data.snapshot,done=new Set(plan.completed),next=plan.stops.find(s=>!done.has(s.id))?.id;
  el('stops').replaceChildren();
  plan.stops.forEach((s,i)=>{const row=document.createElement('li'),badge=document.createElement('span'),body=document.createElement('div');badge.className='badge';badge.textContent=done.has(s.id)?'✓':String(i+1);const title=document.createElement('p'),place=document.createElement('p'),state=document.createElement('span');title.className='errand-title';title.textContent=s.title;place.className='place';place.textContent=s.place;state.className='state';state.textContent=done.has(s.id)?'Done':s.id===next?'Next':'Planned';body.append(title,place,state);row.append(badge,body);el('stops').append(row);});
  el('progress').textContent=done.size+' of '+plan.stops.length+' done';
  el('status').textContent='Shared until '+new Date(expiry).toLocaleTimeString([],{hour:'numeric',minute:'2-digit'})+' · Anyone with this link can view';
  el('trip').hidden=false;el('unavailable').hidden=true;updateLocation();
  clearTimeout(expiryTimer);expiryTimer=setTimeout(unavailable,Math.max(0,expiry-Date.now()));
  if(!mapAttempted){mapAttempted=true;loadMap();}
}
async function load(){
  if(loading||document.hidden)return;loading=true;
  try{const response=await fetch('/v1/shares/'+parsed[1],{headers:{Authorization:'Bearer '+parsed[2]},cache:'no-store',redirect:'error'});if(response.status===404||response.status===403)return unavailable();if(!response.ok)throw Error();render(await response.json());}
  catch{clearLocation();el('status').textContent='Connection lost. Trying again when this page is visible.';if(expiry&&expiry<=Date.now())unavailable();}
  finally{loading=false;}
}
async function loadMap(){
  if(!current)return;el('retry-map').disabled=true;el('map').hidden=false;
  try{
    if(!globalThis.google?.maps){const response=await fetch('/share/config',{cache:'no-store'});if(!response.ok)throw Error();const config=await response.json();if(!config.mapsKey)throw Error();
      await new Promise((resolve,reject)=>{const script=document.createElement('script');const timer=setTimeout(()=>reject(Error()),15000);globalThis.waydayMapsReady=()=>{clearTimeout(timer);resolve();};globalThis.gm_authFailure=()=>{clearTimeout(timer);reject(Error());el('map-error').hidden=false;};script.src='https://maps.googleapis.com/maps/api/js?key='+encodeURIComponent(config.mapsKey)+'&loading=async&callback=waydayMapsReady';script.onerror=()=>{clearTimeout(timer);reject(Error());};document.head.append(script);});}
    const plan=current.snapshot;map=new google.maps.Map(el('map'),{center:{lat:plan.route[0][0],lng:plan.route[0][1]},zoom:13,mapTypeControl:false,streetViewControl:false,fullscreenControl:false,gestureHandling:'cooperative'});
    overlays.forEach(o=>o.setMap(null));overlays=[];routeBounds=new google.maps.LatLngBounds();const path=plan.route.map(([lat,lng])=>({lat,lng}));path.forEach(p=>routeBounds.extend(p));overlays.push(new google.maps.Polyline({map,path,strokeColor:'#285c86',strokeWeight:5,strokeOpacity:1}));
    overlays.push(marker(coordinate(plan.start),'S'));plan.stops.forEach((s,i)=>overlays.push(marker(coordinate(s),String(i+1))));overlays.push(marker(coordinate(plan.destination),'F'));map.fitBounds(routeBounds,36);el('map-error').hidden=true;updateLocation();
  }catch{el('map').hidden=true;el('map-error').hidden=false;}finally{el('retry-map').disabled=false;}
}
el('retry-map').addEventListener('click',loadMap);el('whole-trip').addEventListener('click',()=>{if(map&&routeBounds)map.fitBounds(routeBounds,36);});
document.addEventListener('visibilitychange',()=>{if(document.hidden){clearInterval(poll);clearLocation();}else if(expiry&&Date.now()>=expiry)unavailable();else if(parsed&&location.pathname==='/share/'){load();poll=setInterval(load,15000);}});
async function appLink(){
  if(!parsed)return;
  try{const response=await fetch('/share/config',{cache:'no-store'});if(!response.ok)return;const config=await response.json();if(!/^dev\.wayday\.wayday(?:\.publictest)?$/.test(config.package))return;
    el('open-app').href='intent://'+location.host+location.pathname+'#'+location.hash.slice(1)+'#Intent;scheme=https;package='+config.package+';end';
    el('open-app').hidden=false;
  }catch{/* The browser remains usable without app-link configuration. */}
}
appLink();
addEventListener('hashchange',()=>{unavailable();location.reload();});
if(!parsed)unavailable();else if(location.pathname==='/pair/'){el('status').textContent='Private pairing invitation';el('pair').hidden=false;}else{load();poll=setInterval(load,15000);setInterval(updateLocation,1000);}
