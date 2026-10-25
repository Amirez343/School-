/* fx.js — ابزارهای حرکت و شیشه‌ی مایع (بدون وابستگی). همه‌ی حلقه‌های حرکتی کوتاه و محدودند؛
   هیچ انیمیشن پیوسته‌ای با جاوااسکریپت اجرا نمی‌شود (پس‌زمینه با CSS و فقط transform حرکت می‌کند). */
(function(){
  var d=document,root=d.documentElement;
  var reduce=matchMedia('(prefers-reduced-motion: reduce)').matches;
  var fine=matchMedia('(hover: hover) and (pointer: fine)').matches;

  /* ---- تشخیص توان دستگاه ---- */
  var mem=navigator.deviceMemory||4,cores=navigator.hardwareConcurrency||4;
  var chromium=!!(navigator.userAgentData&&navigator.userAgentData.brands&&navigator.userAgentData.brands.some(function(b){return /Chromium/.test(b.brand);}));
  if(mem<=2||cores<=4||matchMedia('(prefers-reduced-data: reduce)').matches)root.classList.add('lowfx');
  else if(chromium&&mem>=4&&cores>=6&&!reduce)root.classList.add('refract');

  /* ---- تم روشن/تیره ---- */
  var THEME_KEY='theme';
  function curTheme(){return root.getAttribute('data-theme')==='dark'?'dark':'light';}
  function setTheme(t){root.setAttribute('data-theme',t);try{localStorage.setItem(THEME_KEY,t);}catch(e){}}
  d.addEventListener('click',function(e){var b=e.target.closest&&e.target.closest('#themeBtn');if(b)setTheme(curTheme()==='dark'?'light':'dark');});
  var saved=curTheme();
  addEventListener('beforeprint',function(){saved=curTheme();root.setAttribute('data-theme','light');});
  addEventListener('afterprint',function(){root.setAttribute('data-theme',saved);});

  /* ---- فیلتر شکست نور (فقط یک‌بار، فقط وقتی لازم است) ---- */
  function addFilter(){
    if(!root.classList.contains('refract')||d.getElementById('lg-refract'))return;
    var s=d.createElementNS('http://www.w3.org/2000/svg','svg');
    s.setAttribute('width','0');s.setAttribute('height','0');s.setAttribute('aria-hidden','true');s.style.position='absolute';
    s.innerHTML='<filter id="lg-refract" x="0" y="0" width="100%" height="100%" color-interpolation-filters="sRGB"><feTurbulence type="fractalNoise" baseFrequency="0.012 0.022" numOctaves="2" seed="7" result="n"/><feGaussianBlur in="n" stdDeviation="2" result="nb"/><feDisplacementMap in="SourceGraphic" in2="nb" scale="20" xChannelSelector="R" yChannelSelector="G"/></filter>';
    d.body.appendChild(s);
  }

  /* ---- توقف انیمیشن‌های تزئینی وقتی صفحه دیده نمی‌شود ---- */
  d.addEventListener('visibilitychange',function(){root.classList.toggle('paused',d.hidden);});

  /* ---- نشانگر فنری تب‌ها ---- */
  function moveInd(){
    var bar=d.querySelector('.tabbar');if(!bar)return;
    var on=bar.querySelector('.tab.on');if(!on)return;
    var ind=bar.querySelector('.tabind');
    if(!ind){ind=d.createElement('span');ind.className='tabind';ind.setAttribute('aria-hidden','true');bar.insertBefore(ind,bar.firstChild);}
    ind.style.width=on.offsetWidth+'px';
    ind.style.transform='translate3d('+on.offsetLeft+'px,0,0)';
    bar.classList.add('has-ind');
    if(!bar.classList.contains('ready'))requestAnimationFrame(function(){requestAnimationFrame(function(){bar.classList.add('ready');});});
  }
  var rt;addEventListener('resize',function(){clearTimeout(rt);rt=setTimeout(moveInd,80);});
  if(d.fonts&&d.fonts.ready)d.fonts.ready.then(moveInd);

  /* ---- شمارنده‌ی عددی (فقط یک‌بار هنگام ورود به صفحه) ---- */
  function count(scope){
    if(reduce)return;
    scope.querySelectorAll('.stat .v,.statv').forEach(function(el){
      var t=el.textContent.trim(),m=t.match(/^(\d+(?:\.\d+)?)(٪|%)?$/);if(!m)return;
      var end=parseFloat(m[1]),dec=(m[1].split('.')[1]||'').length,suf=m[2]||'';
      if(!(end>0))return;
      var t0=performance.now(),dur=800;
      (function step(now){
        var p=Math.min(1,(now-t0)/dur),e=1-Math.pow(1-p,3);
        el.textContent=(end*e).toFixed(dec)+suf;
        if(p<1)requestAnimationFrame(step);else el.textContent=t;
      })(t0);
    });
  }

  /* ---- نمایان‌شدن با اسکرول (فقط کارت‌های پایین‌تر از صفحه) ---- */
  var io=null;
  function reveal(view){
    if(reduce||!('IntersectionObserver' in window))return;
    if(io)io.disconnect();
    io=new IntersectionObserver(function(es){es.forEach(function(en){if(en.isIntersecting){en.target.classList.add('in');io.unobserve(en.target);}});},{threshold:.06,rootMargin:'0px 0px -5% 0px'});
    view.querySelectorAll(':scope>.card').forEach(function(c){
      if(c.getBoundingClientRect().top>innerHeight*.92){c.classList.add('rv');io.observe(c);}
    });
  }

  /* ---- ورود مرحله‌ای محتوا ---- */
  var done=false;
  function afterShow(opts){
    moveInd();
    var view=d.getElementById('view');if(!view)return;
    if(opts&&opts.once){if(done)return;done=true;}
    view.querySelectorAll('.rv').forEach(function(x){x.classList.remove('rv','in');});
    if(reduce)return;
    var i=0;Array.prototype.forEach.call(view.children,function(c){c.style.setProperty('--i',Math.min(i++,9));});
    view.querySelectorAll('.stat').forEach(function(s,j){s.style.setProperty('--j',Math.min(j,8));});
    view.classList.remove('enter');void view.offsetWidth;view.classList.add('enter');
    clearTimeout(afterShow.t);afterShow.t=setTimeout(function(){view.classList.remove('enter');},1700);
    reveal(view);count(view);
  }

  /* ---- شیشه‌ی واکنش‌گرا به نشانگر: نور، تیلت، جاذبه‌ی مغناطیسی (فقط ماوس) ---- */
  if(fine&&!reduce){
    var litEl=null,tiltEl=null,magEl=null,ev=null,raf=0;
    function reset(el,props){if(!el)return;props.forEach(function(p){el.style.removeProperty(p);});}
    function frame(){
      raf=0;if(!ev)return;
      var t=ev.target;if(!t||!t.closest)return;
      var card=t.closest('.card');
      if(card!==litEl){if(litEl)litEl.classList.remove('lit');litEl=card;if(card)card.classList.add('lit');}
      if(card){var r=card.getBoundingClientRect();card.style.setProperty('--mx',(ev.clientX-r.left)+'px');card.style.setProperty('--my',(ev.clientY-r.top)+'px');}
      var st=t.closest('.stat');
      if(st!==tiltEl){if(tiltEl){tiltEl.classList.remove('tilting');reset(tiltEl,['--rx','--ry']);}tiltEl=st;if(st)st.classList.add('tilting');}
      if(st){var q=st.getBoundingClientRect(),x=(ev.clientX-q.left)/q.width-.5,y=(ev.clientY-q.top)/q.height-.5;st.style.setProperty('--rx',(-y*7).toFixed(2)+'deg');st.style.setProperty('--ry',(x*7).toFixed(2)+'deg');}
      var mg=t.closest('.btn.p');
      if(mg!==magEl){if(magEl)reset(magEl,['--tx-','--ty-']);magEl=mg;}
      if(mg&&!mg.disabled){var b=mg.getBoundingClientRect();mg.style.setProperty('--tx-',((ev.clientX-(b.left+b.width/2))*.12).toFixed(1)+'px');mg.style.setProperty('--ty-',((ev.clientY-(b.top+b.height/2))*.18).toFixed(1)+'px');}
    }
    d.addEventListener('pointermove',function(e){if(e.pointerType==='touch')return;ev=e;if(!raf)raf=requestAnimationFrame(frame);},{passive:true});
    d.addEventListener('pointerleave',function(){ev=null;if(litEl)litEl.classList.remove('lit');reset(tiltEl,['--rx','--ry']);reset(magEl,['--tx-','--ty-']);litEl=tiltEl=magEl=null;});
  }

  /* ---- دکمه‌ی شناور ذخیره ---- */
  function setFab(target){
    var f=d.getElementById('fab');if(!f)return;
    f.classList.toggle('show',!!target);
    f.onclick=target?function(){var b=target();if(b&&!b.disabled)b.click();}:null;
  }

  function init(){addFilter();requestAnimationFrame(moveInd);}
  if(d.readyState==='loading')d.addEventListener('DOMContentLoaded',init);else init();

  window.FX={afterShow:afterShow,moveInd:moveInd,count:count,setFab:setFab,reduce:reduce};
})();
