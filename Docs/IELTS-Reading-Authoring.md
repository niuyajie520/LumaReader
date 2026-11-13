# 添加雅思阅读题目

正式文章放在 `Deferred/StudyCenter/Resources/IELTSReadingSamples.json`。复制对应的题组结构，替换题干、选项和答案。其他题型的完整原创示例在同目录的 `IELTSReadingLayoutSample.json`。应用通过题组的 `type` 选择布局，追加已有题型的题目只需改数据。

- 每篇文章使用唯一的正整数 `id`。题号在同一篇文章内唯一，题组使用首题的题号标识。
- 判断题的答案填写屏幕上的完整选项。选择和匹配题填写选项字母，选项写成 `["A", "选项内容"]`。多选题设 `requiredSelections`，并将答案写成逗号分隔的字母，例如 `"A,D"`。
- 句子和摘要用 `[题号]` 放置行内输入框。笔记和流程图把每个项目或步骤写在 `context` 的单独一行。表格用二维数组 `table`，首行是表头，各单元格也可使用 `[题号]`。
- 图示使用 PNG。将它加入 StudyCenter 的 Swift Package 资源，`diagramAsset` 填无扩展名的文件名。`diagramLabels` 给每题配置左上角起算、介于 0 和 1 的相对位置 `x` 和 `y`。
- 填空的其他可接受答案可以放进 `acceptableAnswers`。
