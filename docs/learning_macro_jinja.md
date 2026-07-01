# Learning dbt Macros and Jinja

This guide is meant to teach Jinja in dbt from the ground up.

If you are fresh out of school and opening a dbt project for the first time, the biggest thing to understand is this:

**dbt is mostly SQL, with Jinja layered on top to make SQL dynamic, reusable, and aware of your project context.**

You are not replacing SQL with Jinja. You are using Jinja to help generate SQL.

A clean mental model is:

- **SQL** does the data work
- **Jinja** helps you write smarter SQL
- **Macros** are reusable Jinja functions
- **dbt context** gives you project-aware helpers like `ref()`, `source()`, `target`, and `this`

---

## 1. What is Jinja in dbt?

Jinja is a templating language. dbt reads your `.sql` and `.yml` files, evaluates any Jinja inside them, and then compiles the result into executable SQL.

That means this dbt model:

```sql
select *
from {{ ref('stg_orders') }}
```

gets compiled into something like:

```sql
select *
from ANALYTICS.STAGING.STG_ORDERS
```

The exact compiled relation depends on your environment, target, and adapter.

So when you write Jinja in dbt, you are usually doing one of these things:

- injecting a model or source name dynamically
- applying model configuration
- reusing SQL patterns
- looping over repeated logic
- branching with conditions
- logging debug information
- occasionally running a query at execution time

---

## 2. The three Jinja syntaxes you need to know

These are the foundation.

### A. Expression syntax: `{{ ... }}`

Use this when you want Jinja to **print or return something into the compiled output**.

Example:

```sql
select {{ "customer_id" }} as id
```

This renders as:

```sql
select customer_id as id
```

In dbt, the most common expression examples are:

```sql
{{ ref('stg_orders') }}
{{ source('raw', 'orders') }}
{{ config(materialized='table') }}
{{ var('start_date') }}
{{ env_var('DBT_ENV') }}
{{ my_macro('amount') }}
```

Use `{{ ... }}` when you want something to appear in the compiled SQL.

---

### B. Statement syntax: `{% ... %}`

Use this when you want Jinja to **do something**, such as control flow or variable assignment.

Examples include:

- `if`
- `for`
- `set`
- `do`
- `macro`
- `endmacro`

Example:

```sql
{% set cols = ['order_id', 'customer_id', 'amount'] %}
```

This does not print anything directly. It creates a variable named `cols`.

---

### C. Comment syntax: `{# ... #}`

Use this for Jinja comments.

```sql
{# this comment will not appear in compiled SQL #}
select 1 as id
```

This is different from SQL comments like `-- comment`, which do appear in the compiled SQL.

---

## 3. The simplest mental model

If you remember only one thing, remember this:

- `{{ ... }}` = **print something**
- `{% ... %}` = **do something**
- `{# ... #}` = **comment something**

That mental model will carry you through most dbt work.

---

## 4. Why dbt uses Jinja

Without Jinja, your dbt project would be repetitive and fragile.

Imagine typing full warehouse table names everywhere, manually repeating the same CASE statements, or duplicating the same SQL transformation in ten files.

Jinja helps with:

### Reuse
Instead of rewriting the same SQL, you can wrap it in a macro.

### Maintainability
Instead of hardcoding relation names, use `ref()` and let dbt handle lineage and naming.

### Safety
`ref()` and `source()` make dependencies explicit in the DAG.

### Flexibility
You can run different logic in `dev` and `prod`, or generate repetitive SQL from a loop.

### Project awareness
Jinja in dbt knows things regular SQL does not know, like the current target schema or the current model relation.

---

## 5. Core dbt Jinja functions and objects

These are the most important dbt-specific pieces.

## `ref()`

`ref()` points to another dbt model.

```sql
select *
from {{ ref('stg_orders') }}
```

Why it matters:

- builds the dependency graph
- resolves the correct relation name
- keeps your project environment-aware
- avoids hardcoding database and schema names

Use `ref()` for dbt models.

---

## `source()`

`source()` points to a declared source table.

```sql
select *
from {{ source('raw', 'orders') }}
```

Why it matters:

- gives you source lineage
- documents raw inputs
- works cleanly with source freshness and testing

Use `source()` for raw tables defined in source YAML.

---

## `config()`

`config()` sets model behavior.

```sql
{{ config(materialized='table') }}
```

Common config examples:

```sql
{{ config(materialized='view') }}
{{ config(materialized='incremental', unique_key='order_id') }}
{{ config(tags=['finance']) }}
{{ config(schema='marts') }}
```

In your active demo model, this pattern is already in use:

```sql
{{ config(
    materialized='table',
    tags=['macro_demo', 'demo_09'],
    post_hook="{{ apply_cluster_by(['visit_date', 'ticket_type']) }}"
) }}
```

That shows an important point: dbt config itself can call macros.

---

## `var()`

`var()` reads variables passed from `dbt_project.yml` or the CLI.

```sql
select '{{ var("country_code", "US") }}' as country_code
```

The second argument is the default.

This is useful when you want a model to behave differently based on environment or a runtime parameter.

---

## `env_var()`

`env_var()` reads environment variables.

```sql
select '{{ env_var("DBT_ENV") }}' as env_name
```

Use this for environment-dependent settings, secrets references, or deployment-specific values.

---

## `target`

`target` is an object that tells you about the active dbt target.

Common fields:

- `target.name`
- `target.schema`
- `target.database`
- `target.type`

Example:

```sql
{% if target.name == 'dev' %}
    select *
    from {{ ref('stg_orders') }}
    where order_date >= current_date - 7
{% endif %}
```

This is useful for development-only filters, debugging, or environment-specific behavior.

---

## `this`

`this` refers to the current model relation.

```sql
select * from {{ this }}
```

You will usually see `this` in incremental models or macros.

Example:

```sql
{{ config(materialized='incremental') }}

select *
from {{ ref('stg_orders') }}

{% if is_incremental() %}
where updated_at > (select max(updated_at) from {{ this }})
{% endif %}
```

Here, `this` means the target table being incrementally updated.

---

## `is_incremental()`

This helper returns `true` when the current model is running incrementally.

Example:

```sql
{{ config(materialized='incremental') }}

select *
from {{ ref('stg_orders') }}

{% if is_incremental() %}
where updated_at > (select max(updated_at) from {{ this }})
{% endif %}
```

This is one of the most common dbt Jinja patterns.

---

## 6. Variables with `{% set %}`

`set` lets you create a variable inside Jinja.

### Simple variable

```sql
{% set model_name = 'stg_orders' %}
```

### List variable

```sql
{% set cols = ['order_id', 'customer_id', 'amount'] %}
```

### Multi-line SQL variable

```sql
{% set query %}
    select distinct status
    from {{ ref('stg_orders') }}
{% endset %}
```

This is very common in macros when you want to build a query and pass it into `run_query()`.

Why `set` matters:

- makes repeated logic cleaner
- avoids copy-pasting strings or lists
- makes loops and macros easier to read
- helps break complex Jinja into smaller steps

---

## 7. Conditional logic with `{% if %}`

Use `if` when you want Jinja to branch.

Example:

```sql
select *
from {{ ref('stg_orders') }}
{% if target.name == 'dev' %}
where created_at >= current_date - 7
{% endif %}
```

This compiles differently depending on the environment.

You can also use `elif` and `else`.

```sql
{% if target.name == 'prod' %}
    {% set row_limit = 1000000 %}
{% elif target.name == 'qa' %}
    {% set row_limit = 10000 %}
{% else %}
    {% set row_limit = 100 %}
{% endif %}
```

Good uses of `if` in dbt:

- environment-specific filters
- incremental conditions
- optional logic driven by vars
- conditional configuration inside macros

A common gotcha: keep business logic in SQL when possible. Use Jinja conditionals for structure and environment-awareness, not for making models overly clever.

---

## 8. Repetition with `{% for %}` loops

Loops are one of the most practical Jinja features.

They are useful when you need to generate repeated SQL patterns.

Example:

```sql
{% set metrics = ['revenue', 'cost', 'profit'] %}

select
{% for metric in metrics %}
    sum({{ metric }}) as total_{{ metric }}{% if not loop.last %},{% endif %}
{% endfor %}
from {{ ref('fct_orders') }}
```

This compiles into:

```sql
select
    sum(revenue) as total_revenue,
    sum(cost) as total_cost,
    sum(profit) as total_profit
from ANALYTICS.MARTS.FCT_ORDERS
```

Why loops are valuable:

- reduce repetitive SQL
- keep repeated patterns consistent
- make pivot-style logic easier
- generate repetitive metrics or CASE expressions

### Loop helpers

Inside a loop, Jinja provides a `loop` object.

Common properties:

- `loop.first`
- `loop.last`
- `loop.index`   (starts at 1)
- `loop.index0`  (starts at 0)

Example:

```sql
{% for col in ['a', 'b', 'c'] %}
    -- column {{ loop.index }} is {{ col }}
{% endfor %}
```

### The comma pattern

One of the most common beginner questions is: how do I avoid a trailing comma?

This is the standard pattern:

```sql
{% for col in ['order_id', 'customer_id', 'amount'] %}
    {{ col }}{% if not loop.last %},{% endif %}
{% endfor %}
```

That `if not loop.last` is a very common dbt Jinja pattern.

---

## 9. The `{% do %}` statement

`do` runs an expression **without printing its return value**.

This is especially useful for functions whose purpose is side effects, not SQL output.

The classic example is logging:

```sql
{% do log('Starting model compilation', info=true) %}
```

If you wrote:

```sql
{{ log('Starting model compilation', info=true) }}
```

then you would be treating it like something to print into the SQL output, which is usually not what you want.

Use `do` for actions.

Common uses:

- `log()`
- list mutation in advanced macros
- actions where the return value is not meant to be rendered

A clean mental model is:

- use `{{ ... }}` when the result should appear in SQL
- use `{% do ... %}` when you want the action to happen quietly

---

## 10. Logging with `log()`

`log()` writes messages to dbt logs.

Example:

```sql
{% do log('Building dynamic columns', info=true) %}
```

You will mainly use this inside macros when debugging.

### Common patterns

Info-level log:

```sql
{% do log('Running query for dimension values', info=true) %}
```

Less prominent log:

```sql
{% do log('Debug detail here', info=false) %}
```

Why logging matters:

- helps you understand macro behavior
- makes debugging easier
- gives visibility into dynamic SQL generation
- helps teammates understand what a macro is doing during execution

Use logs sparingly and make them meaningful. Too much logging turns into noise fast.

---

## 11. Running SQL during execution with `run_query()`

`run_query()` executes a SQL statement from inside Jinja and returns a result object.

This is powerful and a little dangerous if overused.

### Basic example

```sql
{% set query %}
    select distinct status
    from {{ ref('stg_orders') }}
{% endset %}

{% set results = run_query(query) %}
```

If execution is happening, `results` will contain query output.

A more complete example:

```sql
{% set query %}
    select distinct status
    from {{ ref('stg_orders') }}
    order by 1
{% endset %}

{% set results = run_query(query) %}

{% if execute %}
    {% set statuses = results.columns[0].values() %}
{% else %}
    {% set statuses = [] %}
{% endif %}
```

Now you can loop through `statuses`.

### Why use `run_query()`?

Useful cases include:

- building dynamic pivot columns
- reading metadata tables
- generating SQL from warehouse values
- introspection in advanced macros

### Important warning: use `if execute`

This is one of the most important concepts for beginners.

During parse/compile phases, dbt may evaluate Jinja without actually executing warehouse queries. In those situations, `run_query()` may not behave the way you expect.

So the safe pattern is:

```sql
{% set results = run_query(query) %}

{% if execute %}
    {% set values = results.columns[0].values() %}
{% else %}
    {% set values = [] %}
{% endif %}
```

### Rule of thumb

Use `run_query()` when you genuinely need metadata or dynamic values from the warehouse.

If plain SQL can solve the problem cleanly, keep it in SQL. Overusing `run_query()` makes dbt projects harder to reason about.

---

## 12. Filters in Jinja

Filters transform values.

Syntax:

```sql
{{ value | filter_name }}
```

Examples:

```sql
{{ 'orders' | upper }}
{{ 'ORDERS' | lower }}
{{ 'hello world' | replace(' ', '_') }}
```

Using a list with `join`:

```sql
{% set cols = ['order_id', 'customer_id', 'amount'] %}
{{ cols | join(', ') }}
```

Common filters you may see:

- `upper`
- `lower`
- `replace`
- `trim`
- `length`
- `join`

Filters are helpful for formatting strings inside generated SQL or macro logic.

---

## 13. Jinja tests

Jinja tests let you check what something is.

Examples:

```sql
{% if my_var is none %}
    {% do log('Variable is missing', info=true) %}
{% endif %}
```

```sql
{% if my_list is not none %}
    {% do log('List exists', info=true) %}
{% endif %}
```

These are more common in macros than in everyday models.

---

## 14. Whitespace control

Jinja can create messy compiled SQL if you are not careful with whitespace. You can trim whitespace by adding `-`.

Example:

```sql
{%- set cols = ['a', 'b'] -%}
select
{%- for col in cols -%}
    {{ col }}{%- if not loop.last %},{% endif %}
{%- endfor %}
from my_table
```

This is more advanced and mostly useful when writing polished macros.

For beginners, it is fine to ignore whitespace control until your Jinja starts getting hard to read.

---

## 15. What is a macro?

A macro is a reusable Jinja function defined in the `macros/` directory.

Think of a macro as a way to package logic once and call it many times.

### Example macro

```sql
{% macro cents_to_dollars(column_name) %}
    ({{ column_name }} / 100.0)
{% endmacro %}
```

### Use it in a model

```sql
select
    {{ cents_to_dollars('amount_cents') }} as amount_usd
from {{ ref('stg_orders') }}
```

This is one of the cleanest uses of Jinja in dbt: repeating a small SQL pattern consistently.

---

## 16. Macro parameters

Macros can accept inputs.

```sql
{% macro add_prefix(prefix, col) %}
    {{ prefix }}_{{ col }}
{% endmacro %}
```

Usage:

```sql
select '{{ add_prefix("total", "revenue") }}' as example
```

You can pass:

- strings
- numbers
- lists
- booleans
- expressions

Example with a list:

```sql
{% macro select_columns(cols) %}
    {% for col in cols %}
        {{ col }}{% if not loop.last %}, {% endif %}
    {% endfor %}
{% endmacro %}
```

Then:

```sql
select
    {{ select_columns(['order_id', 'customer_id', 'amount']) }}
from {{ ref('stg_orders') }}
```

---

## 17. Macros vs models

This distinction matters.

### Models
Models produce relations in your warehouse, like views or tables.

Example:

```sql
models/staging/stg_orders.sql
```

### Macros
Macros generate SQL or perform helper logic. They do not materialize as warehouse objects on their own.

Example:

```sql
macros/cents_to_dollars.sql
```

Use a **model** when you want a dataset.

Use a **macro** when you want reusable logic.

A good rule: if the output should be a table or view, use a model. If the output should be a reusable SQL snippet or helper behavior, use a macro.

---

## 18. A practical example: looping over columns

Suppose you want aggregated columns for a few metrics.

Without Jinja:

```sql
select
    sum(revenue) as total_revenue,
    sum(cost) as total_cost,
    sum(profit) as total_profit
from {{ ref('fct_orders') }}
```

With Jinja:

```sql
{% set metrics = ['revenue', 'cost', 'profit'] %}

select
{% for metric in metrics %}
    sum({{ metric }}) as total_{{ metric }}{% if not loop.last %},{% endif %}
{% endfor %}
from {{ ref('fct_orders') }}
```

Why this is better:

- easier to extend
- less copy-paste
- less risk of inconsistent alias naming

Why this can become worse if overdone:

- harder for new teammates to read
- debugging compiled SQL becomes more important
- simple SQL can become hidden behind abstraction

That tradeoff is central to good dbt style.

---

## 19. A practical example: dynamic filtering by target

```sql
select *
from {{ ref('stg_orders') }}
{% if target.name == 'dev' %}
where order_date >= current_date - 3
{% endif %}
```

Why teams do this:

- development runs are faster
- production remains complete
- local iteration is easier

Be disciplined here. Development filters are useful. Accidentally letting environment logic spread everywhere is messy.

---

## 20. A practical example: `run_query()` plus `log()`

This example shows several concepts together.

```sql
{% set query %}
    select distinct ticket_type
    from {{ ref('fct_visits') }}
    order by 1
{% endset %}

{% do log('Running query to fetch ticket types', info=true) %}
{% set results = run_query(query) %}

{% if execute %}
    {% set ticket_types = results.columns[0].values() %}
    {% do log('Ticket types found: ' ~ (ticket_types | join(', ')), info=true) %}
{% else %}
    {% set ticket_types = [] %}
{% endif %}
```

Concepts used here:

- `{% set %}` to build SQL
- `{% do log() %}` to write messages
- `run_query()` to execute SQL
- `if execute` to protect execution-time logic
- `join` filter to format output

This is a realistic macro pattern.

---

## 21. A practical example tied to your demo model

Your active file `models/macro_demos/demo_09_clustering.sql` contains:

```sql
{{ config(
    materialized='table',
    tags=['macro_demo', 'demo_09'],
    post_hook="{{ apply_cluster_by(['visit_date', 'ticket_type']) }}"
) }}

select
    ticket_id,
    customer_id,
    visit_date,
    ticket_type,
    total_visit_spend,
    avg_rating
from {{ ref('fct_visits') }}
```

This example is useful because it shows multiple dbt Jinja ideas in one small model:

### `config()`
This sets materialization, tags, and a post-hook.

### `ref('fct_visits')`
This creates a dependency on another model and resolves the correct relation name.

### `apply_cluster_by([...])`
This is a macro call inside config.

### List input `['visit_date', 'ticket_type']`
That list is passed into the macro so it can generate clustering SQL.

This is a good example of practical Jinja: short, focused, and useful.

---

## 22. The `execute` variable

`execute` is a dbt-provided boolean that tells you whether dbt is in an execution context.

Why it matters:

- some Jinja runs during parsing or compilation
- some logic only makes sense when dbt is actually executing SQL
- `run_query()` and similar operations often need protection with `if execute`

Example:

```sql
{% set results = run_query('select 1 as id') %}

{% if execute %}
    {% set ids = results.columns[0].values() %}
{% else %}
    {% set ids = [] %}
{% endif %}
```

If you skip this protection in the wrong place, you can get confusing parse/compile issues.

---

## 23. Common beginner mistakes

These are the ones worth watching for.

### Mistake 1: Using Jinja where plain SQL is simpler

Bad pattern:

```sql
{% if var('country') == 'US' %}
    select * from table_us
{% else %}
    select * from table_other
{% endif %}
```

Sometimes this is valid, but often a cleaner relational design or source/model separation is better.

### Mistake 2: Hardcoding relation names instead of using `ref()` and `source()`

Avoid:

```sql
from ANALYTICS.STAGING.STG_ORDERS
```

Prefer:

```sql
from {{ ref('stg_orders') }}
```

### Mistake 3: Forgetting `if execute` around `run_query()` result handling

This is a common gotcha.

### Mistake 4: Writing loops that generate broken SQL

Usually this happens because of commas, spacing, or aliases.

### Mistake 5: Over-abstracting simple logic

If your teammate needs ten minutes to understand a macro that saves five lines of SQL, the abstraction probably is not worth it.

### Mistake 6: Mixing business logic and macro cleverness

Business logic should still be easy to read in SQL.

---

## 24. When to use Jinja in dbt

Use Jinja when it gives you a real payoff.

### Good times to use Jinja

- repeated select expressions
- repeated CASE patterns
- environment-aware development filters
- incremental logic
- reusable formatting or SQL snippets
- metadata-driven macros
- post-hooks and config helpers

### Be cautious when using Jinja for

- large branches of business logic
- dynamic query generation that hides model grain
- complicated nested loops
- heavy warehouse introspection for routine transformations

A strong dbt project usually keeps models readable and uses macros to remove the right amount of repetition.

---

## 25. How to think about compiled SQL

When Jinja gets confusing, always come back to this question:

**What SQL will dbt compile from this?**

That question will save you.

If a loop, macro, or condition feels hard to reason about, inspect the compiled SQL.

That is usually where the real answer lives.

A lot of Jinja confusion disappears once you realize dbt is just building a final SQL string for the warehouse to execute.

---

## 26. Teaching examples by concept

### Example: `{{ ... }}` expression

```sql
select * from {{ ref('stg_customers') }}
```

### Example: `{% set %}`

```sql
{% set dims = ['country', 'device_type', 'channel'] %}
```

### Example: `{% for %}`

```sql
{% for dim in dims %}
    {{ dim }}{% if not loop.last %}, {% endif %}
{% endfor %}
```

### Example: `{% if %}`

```sql
{% if target.name == 'dev' %}
where event_date >= current_date - 7
{% endif %}
```

### Example: `{% do %}`

```sql
{% do log('Compiling customer dimension logic', info=true) %}
```

### Example: `run_query()`

```sql
{% set query %}
    select count(*)
    from {{ ref('stg_customers') }}
{% endset %}

{% set results = run_query(query) %}
```

### Example: macro definition

```sql
{% macro null_safe_sum(column_name) %}
    coalesce(sum({{ column_name }}), 0)
{% endmacro %}
```

### Example: macro call

```sql
select {{ null_safe_sum('revenue') }} as total_revenue
from {{ ref('fct_orders') }}
```

---

## 27. Best practices

These will keep your dbt project healthy.

### Prefer clarity over cleverness

A readable model beats a magical one.

### Use `ref()` and `source()` consistently

That keeps lineage and dependency management clean.

### Keep macros focused

A good macro usually does one thing well.

### Reach for loops when repetition is real

Do not force a loop just to be fancy.

### Guard execution-only behavior

Use `if execute` around result handling from `run_query()`.

### Log intentionally

Write logs that would actually help someone debug behavior.

### Keep business logic visible

Your marts and staging models should still be understandable to someone reading SQL.

---

## 28. A beginner-friendly summary

If you are new to dbt, here is the practical order to learn things:

1. Learn `ref()` and `source()` first
2. Learn `config()` next
3. Learn `set`, `if`, and `for`
4. Learn how macros work
5. Learn `do log()` for debugging
6. Learn `run_query()` after you are comfortable with the basics
7. Learn advanced whitespace control and macro patterns later

That order maps well to how most analytics engineers actually grow in dbt.

---

## 29. Final cheat sheet

### Syntax types

```sql
{{ ... }}   -- print/output something
{% ... %}   -- do/control something
{# ... #}   -- comment something
```

### Most-used dbt helpers

```sql
ref()
source()
config()
var()
env_var()
target
this
is_incremental()
```

### Most-used Jinja statements

```sql
set
if
for
do
macro
```

### Most-used advanced helpers

```sql
log()
run_query()
execute
loop.last
```

---

## 30. Final advice

The best dbt Jinja is usually boring in a good way.

If Jinja helps you remove repetition, make config reusable, or keep a model environment-aware, it is doing its job.

If Jinja makes a model feel like metaprogramming homework, pull it back.

Aim for this standard:

- a fresh teammate can read the model
- the compiled SQL is still easy to understand
- the macro saves real repetition
- the DAG stays clear

That is the sweet spot.
