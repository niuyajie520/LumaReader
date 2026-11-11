from pathlib import Path
import re, hashlib, difflib, json, sys
if len(sys.argv) != 2:
 raise SystemExit("Usage: python3 Review/verify-preservation.py ORIGINAL_SOURCE_ROOT")
base=Path(sys.argv[1]);root=Path(__file__).resolve().parents[1]
old=(base/'Deferred/StudyCenter/StudyHome.swift').read_text();new=(root/'Deferred/StudyCenter/StudyHome.swift').read_text()
checks=[]
def check(label,result):
 checks.append({'check':label,'status':'已静态审查' if result else 'FAILED'})
 if not result: raise AssertionError(label)
def member(s,name):
 match=re.search(r'^    (?:@ViewBuilder )?(?:private |public |static |nonisolated )*(?:func|var) '+re.escape(name)+r'\b',s,re.M)
 assert match,name
 end=re.search(r'^    }',s[match.start():],re.M)
 assert end
 return s[match.start():match.start()+end.end()]
for name in ['triggerDictationErrorAnimation','submitCurrentDictation','speakCurrentWord','speakArbitraryWord','recentWrongWordStrings','dictationStaticStatusLine','startSlowReactionDictation','buildFirstLetterHint','dictationMorePanel']:
 check(name+' body unchanged',member(old,name)==member(new,name))
start='@MainActor\nprivate struct DictationShakeEffect'
check('DictationShakeEffect unchanged',old[old.index(start):old.index('/// 正在编辑')]==new[new.index(start):new.index('/// 正在编辑')])
check('business model unchanged',old[old.index('    @MainActor\n    final class HostStateModel'):old.index('    @State private var showWritingExit')]==new[new.index('    @MainActor\n    final class HostStateModel'):new.index('    @State private var showWritingExit')])
for token in ['.focused($answerFocused)','.autocorrectionDisabled()', '.disabled(!listeningDailyTimer.running || kokoro.isSwitching)', '.accessibilityIdentifier("study.dictation.answer")']:
 check(token, token in member(new,'dictationAnswerBox'))
check('Direct binding retained','text: $vm.dictationInput' in member(new,'dictationAnswerBox'))
check('Submit handler retained','.onSubmit {\n                    submitCurrentDictation()\n                }' in member(new,'dictationAnswerBox'))
check('All accessibilityIdentifier literals retained', sorted(re.findall(r'\.accessibilityIdentifier\("([^"]*)"\)',old))==sorted(re.findall(r'\.accessibilityIdentifier\("([^"]*)"\)',new)))
check('All keyboardShortcut declarations retained', sorted(re.findall(r'\.keyboardShortcut\([^\n]*',old))==sorted(re.findall(r'\.keyboardShortcut\([^\n]*',new)))
check('Cmd event monitor unchanged',member(old,'listeningCenterContent').split('guard flags == [.command]')[1]==member(new,'listeningCenterContent').split('guard flags == [.command]')[1])
for token in ['.overlay(shape.strokeBorder(borderCol, lineWidth: dictationErrorFlash ? 2.4 : 1.4))','.shadow(color: (dictationErrorFlash ? Color.red : dictAccentPink).opacity(0.16), radius: 14, x: 0, y: 0)','.modifier(DictationShakeEffect(animatableData: dictationErrorShake))']:
 check('Protected input effect '+token,token in member(old,'dictationAnswerBox') and token in member(new,'dictationAnswerBox'))
# Six unchanged action bodies; presentation helper names may change.
def action(s,title):
 at=s.index('title: '+title,s.index('private '+('var dictationPracticeActions' if 'private var dictationPracticeActions' in s else 'func listeningCenterContent')))
 at=s.index(') {',at)+3
 depth=1;end=at
 while depth:
  if s[end]=='{':depth+=1
  elif s[end]=='}':depth-=1
  end+=1
 return re.sub(r'\s+',' ',s[at:end-1]).strip()
for title in ['"上一个"','kokoro.isPreparingAudio','"慢放"','vm.showMeaning','showFirstLetterHint','"提交"']:
 check('Action unchanged: '+title,action(old,title)==action(new,title))
# All edits in this mixed writing/listening file must land in the approved UI members.
allowed_names=['dictationTopRightCapsules','dictationProgressCard','dictationRecentWrongWordsCard','dictationAnswerBox','dictationBottomCapsuleButton','listeningCenterView','listeningCenterContent','slowReactionWordsDedicatedView','stubbornWordsDedicatedView']
allowed=[]
for name in allowed_names:
 block=member(old,name);a=old.index(block);allowed.append((a,a+len(block)))
state_at=old.index('    @State private var speechSettingsTab')
allowed.append((state_at,state_at))
old_lines=old.splitlines(keepends=True);new_lines=new.splitlines(keepends=True)
positions=[0]
for line in old_lines:positions.append(positions[-1]+len(line))
for tag,al,bl,cl,dl in difflib.SequenceMatcher(None,old_lines,new_lines,autojunk=False).get_opcodes():
 a,b=positions[al],positions[bl]
 if tag!='equal':
  check('Edit confined to listening UI at original line '+str(old.count('\n',0,a)+1),any(lo<=a and b<=hi+2 for lo,hi in allowed))
# Every non-UI source file including writing, reader data and JS/CSS must match.
changed_sources={'Deferred/StudyCenter/StudyHome.swift','Deferred/StudyCenter/Package.swift','Sources/LumaReader/ContentView.swift','Sources/LumaReader/ReadingOutlineView.swift'}
count=0
for p in base.rglob('*'):
 rel=p.relative_to(base).as_posix()
 if p.is_file() and (rel.startswith('Sources/') or rel.startswith('Deferred/') or rel.startswith('Vendor/')) and rel not in changed_sources:
  q=root/rel
  check('Byte-identical: '+rel,q.exists() and p.read_bytes()==q.read_bytes());count+=1
# Reader event handler declarations and actual action bodies are preserved.
ro=(base/'Sources/LumaReader/ContentView.swift').read_text();rn=(root/'Sources/LumaReader/ContentView.swift').read_text()
for name in ['readerChromeVisible','revealReaderChrome','scheduleChromeHide','closeReaderPanels','readerPanelPresented','reading','bookmarkNavigation','notesInspector']:
 check('Reader unchanged: '+name,member(ro,name)==member(rn,name))
for token in ['Button { closeReaderPanels(); store.returnToLibrary() }','Button { activeReaderPanel = nil; showBookSearch.toggle() }','Button { controller.addBookmark() }','Button { closeReaderPanels(); showSettings = true }','Button { store.aiPanelVisible.toggle() }']:
 check('Reader action retained: '+token,ro.count(token)==rn.count(token))
# Contrast: opaque existing tokens, WCAG relative luminance, sRGB alpha compositing.
def rgb(h):return [int(h[i:i+2],16)/255 for i in (0,2,4)]
def lum(c):return sum(w*(x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4) for w,x in zip([.2126,.7152,.0722],c))
def contrast(a,b):x,y=sorted([lum(a),lum(b)]);return (y+.05)/(x+.05)
colors={'primary':'F5EDF1','secondary':'AF98A4','accent':'EF9FC7','background':'120E13','card':'211720','capsule':'382630','pause':'382A1B'}
ratios={}
for fg in ['primary','secondary','accent']:
 for bg in ['background','card','capsule','pause']:
  ratio=contrast(rgb(colors[fg]),rgb(colors[bg]));ratios[fg+'/'+bg]=round(ratio,2);check('Opaque text AA '+fg+'/'+bg,ratio>=4.5)
ratios['submit background/accent']=round(contrast(rgb(colors['background']),rgb(colors['accent'])),2)
check('Submit label AA',ratios['submit background/accent']>=4.5)
summary={'result':'STATIC_REVIEW_ONLY','macOS_compilation':'NOT_RUN_NO_MACOS_SWIFT_TOOLCHAIN','native_UI_tests':'NOT_RUN','unchanged_source_files':count,'contrast_ratios':ratios,'checks':checks}
(root/'Review/static-review.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
print(json.dumps({'status':summary['result'],'checks':len(checks),'unchanged_sources':count,'contrast_ratios':ratios},ensure_ascii=False,indent=2))
