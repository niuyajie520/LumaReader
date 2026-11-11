import re,subprocess,sys,json
R='./'
old=open('./Review/StudyHome.old').read(); new=open(R+'Deferred/StudyCenter/StudyHome.swift').read()
cold=open('./Review/ContentView.old').read(); cnew=open(R+'Sources/LumaReader/ContentView.swift').read()
res=[]
def ck(label,ok): res.append((label,'通过' if ok else '失败'))
def member(s,name):
    m=re.search(r'^    (?:@ViewBuilder )?(?:private |public |static |nonisolated )*(?:func|var) '+re.escape(name)+r'\b',s,re.M)
    if not m: return None
    e=re.search(r'^    }',s[m.start():],re.M); return s[m.start():m.start()+e.end()]
def line(s,sub): return s[:s.index(sub)].count('\n')+1
for n in ['dictationAnswerBox','dictationAnswerHints','triggerDictationErrorAnimation','submitCurrentDictation','speakCurrentWord','speakArbitraryWord','recentWrongWordStrings','dictationStaticStatusLine','dictationMorePanel','buildFirstLetterHint','listeningCenterView']:
    ck(f'{n} 函数体逐字节不变 (新 L{line(new,member(new,n)) if member(new,n) else "?"})', member(old,n) is not None and member(old,n)==member(new,n))
a='private struct DictationShakeEffect'; ck('DictationShakeEffect 不变', old[old.index(a):old.index('/// 正在编辑')]==new[new.index(a):new.index('/// 正在编辑')])
ck('HostStateModel 业务模型不变', old[old.index('final class HostStateModel'):old.index('    @State private var showWritingExit')]==new[new.index('final class HostStateModel'):new.index('    @State private var showWritingExit')])
mon=lambda s: member(s,'listeningCenterContent').split('StudyKeyboardEventMonitor { event in')[1]
ck('AppKit 键盘监听（回车 / ⌘H ⌘/ ⌘R ⌘\'）逐字节不变', mon(old)==mon(new))
for t in ['text: $vm.dictationInput','.focused($answerFocused)','.autocorrectionDisabled()','.disabled(!listeningDailyTimer.running || kokoro.isSwitching)','.accessibilityIdentifier("study.dictation.answer")','.onSubmit {\n                    submitCurrentDictation()\n                }']:
    ck('输入框保留 '+t.split('\n')[0], t in member(new,'dictationAnswerBox'))
ks=lambda s: sorted(re.findall(r'\.keyboardShortcut\([^\n]*',s))
ck('StudyHome 全部 keyboardShortcut 声明不变', ks(old)==ks(new))
ck('ContentView 全部 keyboardShortcut 声明不变', ks(cold)==ks(cnew))
ai=lambda s: sorted(re.findall(r'\.accessibilityIdentifier\("([^"]*)"\)',s))
ck('StudyHome accessibilityIdentifier 不变', ai(old)==ai(new))
def body_after(s,anchor,start_from):
    at=s.index(anchor,s.index(start_from)); at=s.index(') {',at)+3 if anchor.startswith(('title','symbol','label')) else s.index('{',at)+1
    d=1;e=at
    while d:
        if s[e]=='{':d+=1
        elif s[e]=='}':d-=1
        e+=1
    return re.sub(r'\s+',' ',s[at:e-1]).strip()
acts_old={'上一个':body_after(old,'title: "上一个"','private var dictationPracticeActions'),'重播':body_after(old,'symbol: "speaker.wave.2.fill"','private var dictationPracticeActions'),
'慢放':body_after(old,'title: "慢放"','private var dictationPracticeActions'),'中文':body_after(old,'symbol: "character.bubble"','private var dictationPracticeActions'),
'首字母':body_after(old,'symbol: "lightbulb"','private var dictationPracticeActions'),'提交':body_after(old,'title: "提交"','private var dictationPracticeActions')}
acts_new={'上一个':body_after(new,'label: "上一个"','private var dictationPracticeActions'),'重播':body_after(new,'label: "重播"','private var dictationPracticeActions'),
'慢放':body_after(new,'label: "慢放"','private var dictationPracticeActions'),'中文':body_after(new,'symbol: "character.bubble"','private var dictationPracticeActions'),
'首字母':body_after(new,'symbol: "lightbulb"','private var dictationPracticeActions')}
i=new.index('Button {\n                    submitCurrentDictation()',new.index('private var dictationPracticeActions'))
acts_new['提交']=body_after(new,'Button {',new[:i] and 'Button {\n                    submitCurrentDictation()')
for k in acts_old: ck(f'底部动作「{k}」闭包不变', acts_old[k]==acts_new[k])
dis=['disabled: previousDictationWord == nil || vm.dictationMachine.requiresCorrection','!listeningDailyTimer.running || kokoro.isSwitching']
for d in dis: ck('禁用条件保留: '+d, d in member(new,'dictationPracticeActions'))
order=[new.index(x,new.index('private var dictationPracticeActions')) for x in ['label: "上一个"','label: "重播"','label: "慢放"','symbol: "character.bubble"','symbol: "lightbulb"','submitCurrentDictation()']]
ck('六个按钮 Tab 顺序不变（上一个→重播→慢放→中文→首字母→提交）', order==sorted(order))
for t in ['Button { closeReaderPanels(); store.returnToLibrary() }','Button { activeReaderPanel = nil; showBookSearch.toggle() }','readerPanelButton(.contents,symbol:"list.bullet",label:"目录"','readerPanelButton(.notes,symbol:"note.text",label:"书签、高亮与笔记"','Button { closeReaderPanels(); showSettings = true }','Button { store.aiPanelVisible.toggle() }','Button { controller.addBookmark() }',
          '.focused($readerBackFocused)','showBookSearch = false\n            activeReaderPanel = activeReaderPanel == panel ? nil:panel']:
    ck('阅读顶栏动作保留: '+t.split('\n')[0][:60], cold.count(t)==cnew.count(t)==(cold.count(t) or -1))
hl=re.findall(r'\.help\(L10n\.text\("([^"]+)"\)\)',cold); hn=re.findall(r'\.help\(L10n\.text\("([^"]+)"\)\)',cnew)
ck('ContentView help 文案集合不变', sorted(hl)==sorted(hn))
al=lambda s: sorted(re.findall(r'\.accessibilityLabel\(L10n\.text\(([^)]*)\)\)',s))
ck('ContentView accessibilityLabel 文案集合不变', al(cold)==al(cnew))
# left 4 / right 3 order
seg=cnew[cnew.index('if isReadingBook && readerChromeVisible {'):cnew.index('} else if !isReadingBook && !studyVisible {')]
o=[seg.index(x) for x in ['returnToLibrary','showBookSearch.toggle','readerPanelButton(.contents','readerPanelButton(.notes','readerUtilityActions','readerBookmarkAction']]
ck('阅读顶栏顺序：左（返回、搜索、目录、笔记）右（设置、AI | 书签）', o==sorted(o))
u=cnew[cnew.index('private func readerUtilityActions'):cnew.index('private var readerPanelPresented')]
ck('右组内顺序：设置→AI', u.index('showSettings = true')<u.index('aiPanelVisible.toggle()'))
# byte identical files
diff=subprocess.run(['git','-C',R,'diff','--name-only'],capture_output=True,text=True).stdout.split()
for f in ['Deferred/StudyCenter/StudyPromptView.swift','Sources/LumaReader/ReaderController.swift','Sources/LumaReader/NoteActions.swift','Deferred/StudyCenter/DictationPracticeLayout.swift','Deferred/StudyCenter/DictationEngine.swift','Sources/LumaReader/LumaReaderApp.swift','Sources/LumaReader/ReaderKeyboard.swift','Sources/LumaReader/Theme.swift','Sources/LumaReader/MonetTheme.swift']:
    ck('文件逐字节不变: '+f, f not in diff)
ck('改动文件清单', True); res.append(('  → '+', '.join(diff),''))
w=0
for l,s in res: print(('✅ ' if s=='通过' else ('❌ ' if s else ''))+l); w+= s=='失败'
print('失败数',w)
