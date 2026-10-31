(* This file is part of the Catala compiler, a specification language for tax and social benefits
   computation rules. Copyright (C) 2020 Inria, contributors: Denis Merigoux
   <denis.merigoux@inria.fr>, Emile Rolley <emile.rolley@tuta.io>

   Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
   in compliance with the License. You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software distributed under the License
   is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
   or implied. See the License for the specific language governing permissions and limitations under
   the License. *)

(* Defining the lexer macros for Chinese *)

(* Tokens and their corresponding sedlex regexps *)

#define MS_SCOPE "作用域"
#define MR_SCOPE 0x4F5C, 0x7528, 0x57DF
#define MS_CONSEQUENCE "结果"
#define MR_CONSEQUENCE 0x7ED3, 0x679C
#define MS_DATA "数据"
#define MR_DATA 0x6570, 0x636E
#define MS_DEPENDS "依赖于"
#define MR_DEPENDS 0x4F9D, 0x8D56, 0x4E8E
#define MS_DECLARATION "声明"
#define MR_DECLARATION 0x58F0, 0x660E
#define MS_CONTEXT "上下文"
#define MR_CONTEXT 0x4E0A, 0x4E0B, 0x6587
#define MS_DECREASING "递减"
#define MR_DECREASING 0x9012, 0x51CF
#define MS_INCREASING "递增"
#define MR_INCREASING 0x9012, 0x589E
#define MS_OF "取"
#define MR_OF 0x53D6
#define MS_LIST "列表"
#define MR_LIST 0x5217, 0x8868
#define MS_OPTION "可选"
#define MR_OPTION 0x53EF, 0x9009
#define MS_CONTAINS "包含"
#define MR_CONTAINS 0x5305, 0x542B
#define MS_ENUM "枚举"
#define MR_ENUM 0x679A, 0x4E3E
#define MS_SUM "合计"
#define MR_SUM 0x5408, 0x8BA1
#define MS_FILLED "满足"
#define MR_FILLED 0x6EE1, 0x8DB3
#define MS_DEFINITION "定义"
#define MR_DEFINITION 0x5B9A, 0x4E49
#define MS_STATE "状态"
#define MR_STATE 0x72B6, 0x6001
#define MS_LABEL "标签"
#define MR_LABEL 0x6807, 0x7B7E
#define MS_EXCEPTION "例外"
#define MR_EXCEPTION 0x4F8B, 0x5916
#define MS_DEFINED_AS "等于"
#define MR_DEFINED_AS 0x7B49, 0x4E8E
#define MS_MATCH "匹配"
#define MR_MATCH 0x5339, 0x914D
#define MS_WILDCARD "任意"
#define MR_WILDCARD 0x4EFB, 0x610F
#define MS_TYPE "类型"
#define MR_TYPE 0x7C7B, 0x578B
#define MS_WITH "按模式"
#define MR_WITH 0x6309, 0x6A21, 0x5F0F
#define MS_UNDER_CONDITION "在条件下"
#define MR_UNDER_CONDITION 0x5728, 0x6761, 0x4EF6, 0x4E0B
#define MS_IF "如果"
#define MR_IF 0x5982, 0x679C
#define MS_THEN "那么"
#define MR_THEN 0x90A3, 0x4E48
#define MS_ELSE "否则"
#define MR_ELSE 0x5426, 0x5219
#define MS_CONDITION "条件"
#define MR_CONDITION 0x6761, 0x4EF6
#define MS_CONTENT "内容"
#define MR_CONTENT 0x5185, 0x5BB9
#define MS_STRUCT "结构"
#define MR_STRUCT 0x7ED3, 0x6784
#define MS_ASSERTION "断言"
#define MR_ASSERTION 0x65AD, 0x8A00
#define MS_WITH_V "与"
#define MR_WITH_V 0x4E0E
#define MS_FOR "对于"
#define MR_FOR 0x5BF9, 0x4E8E
#define MS_ALL "全部"
#define MR_ALL 0x5168, 0x90E8
#define MS_WE_HAVE "我们有"
#define MR_WE_HAVE 0x6211, 0x4EEC, 0x6709
#define MS_RULE "规则"
#define MR_RULE 0x89C4, 0x5219
#define MS_LET "令"
#define MR_LET 0x4EE4
#define MS_EXISTS "存在"
#define MR_EXISTS 0x5B58, 0x5728
#define MS_IN "处于"
#define MR_IN 0x5904, 0x4E8E
#define MS_AMONG "之中"
#define MR_AMONG 0x4E4B, 0x4E2D
#define MS_COMBINE "合并"
#define MR_COMBINE 0x5408, 0x5E76
#define MS_MAP_EACH "对每个"
#define MR_MAP_EACH 0x5BF9, 0x6BCF, 0x4E2A
#define MS_TO "到"
#define MR_TO 0x5230
#define MS_SUCH "使"
#define MR_SUCH 0x4F7F
#define MS_THAT "得"
#define MR_THAT 0x5F97
#define MS_SORT "排序"
#define MR_SORT 0x6392, 0x5E8F
#define MS_ORDER_ASCENDING "按递增顺序"
#define MR_ORDER_ASCENDING 0x6309, 0x9012, 0x589E, 0x987A, 0x5E8F
#define MS_ORDER_DESCENDING "按递减顺序"
#define MR_ORDER_DESCENDING 0x6309, 0x9012, 0x51CF, 0x987A, 0x5E8F
#define MS_AND_THEN "然后"
#define MR_AND_THEN 0x7136, 0x540E
#define MS_AND "并且"
#define MR_AND 0x5E76, 0x4E14
#define MS_OR "或者"
#define MR_OR 0x6216, 0x8005
#define MS_XOR "异或"
#define MR_XOR 0x5F02, 0x6216
#define MS_NOT "非"
#define MR_NOT 0x975E
#define MS_MAXIMUM "最大"
#define MR_MAXIMUM 0x6700, 0x5927
#define MS_MINIMUM "最小"
#define MR_MINIMUM 0x6700, 0x5C0F
#define MS_IS "是"
#define MR_IS 0x662F
#define MS_OR_IF_LIST_EMPTY "或若列表为空"
#define MR_OR_IF_LIST_EMPTY 0x6216, 0x82E5, 0x5217, 0x8868, 0x4E3A, 0x7A7A
#define MS_BUT_REPLACE "但是替换"
#define MR_BUT_REPLACE 0x4F46, 0x662F, 0x66FF, 0x6362
#define MS_INITIALLY "初始"
#define MR_INITIALLY 0x521D, 0x59CB
#define MS_YEAR "年"
#define MR_YEAR 0x5E74
#define MS_MONTH "月"
#define MR_MONTH 0x6708
#define MS_DAY "天"
#define MR_DAY 0x5929
#define MS_TRUE "真"
#define MR_TRUE 0x771F
#define MS_FALSE "假"
#define MR_FALSE 0x5047
#define MS_INPUT "输入"
#define MR_INPUT 0x8F93, 0x5165
#define MS_OUTPUT "输出"
#define MR_OUTPUT 0x8F93, 0x51FA
#define MS_INTERNAL "内部"
#define MR_INTERNAL 0x5185, 0x90E8

(* Specific delimiters *)

#define MS_MONEY_OP_SUFFIX "¥"
#define MR_MONEY_OP_SUFFIX 0x00A5
#define MC_DECIMAL_SEPARATOR '.'
#define MR_MONEY_PREFIX 0x00A5, Star hspace
#define MR_MONEY_DELIM ','
#define MR_MONEY_SUFFIX ""

(* Builtin types *)

#define MS_INTEGER "整数"
#define MR_INTEGER 0x6574, 0x6570
#define MS_MONEY "金额"
#define MR_MONEY 0x91D1, 0x989D
#define MS_DECIMAL "小数"
#define MR_DECIMAL 0x5C0F, 0x6570
#define MS_DATE "日期"
#define MR_DATE 0x65E5, 0x671F
#define MS_DURATION "期间"
#define MR_DURATION 0x671F, 0x95F4
#define MS_BOOLEAN "布尔"
#define MR_BOOLEAN 0x5E03, 0x5C14
#define MS_POSITION "代码位置"
#define MR_POSITION 0x4EE3, 0x7801, 0x4F4D, 0x7F6E

(* Builtin constructors *)

#define MS_PRESENT "有"
#define MR_PRESENT 0x6709
#define MS_ABSENT "无"
#define MR_ABSENT 0x65E0

(* Builtin functions *)

#define MS_Round "四舍五入"
#define MR_Round 0x56DB, 0x820D, 0x4E94, 0x5165
#define MS_Impossible "不可能"
#define MR_Impossible 0x4E0D, 0x53EF, 0x80FD
#define MS_Cardinal "数值"
#define MR_Cardinal 0x6570, 0x503C

(* Directives *)

#define MR_LAW_INCLUDE "Include"
#define MR_MODULE_DEF "Module"
#define MR_MODULE_USE "Using"
#define MR_MODULE_ALIAS "as"
#define MR_EXTERNAL "external"
#define MX_AT_PAGE \
   '@', Star hspace, "p.", Star hspace, Plus digit -> \
      let s = Utf8.lexeme lexbuf in \
      let i = String.index s '.' in \
      AT_PAGE (int_of_string (String.trim (String.sub s i (String.length s - i))))
