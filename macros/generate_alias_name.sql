{% macro generate_alias_name(custom_alias_name=none, node=none) -%}
    {{ return(
        dbt.generate_alias_name(custom_alias_name, node) | trim | upper
    ) }}
{%- endmacro %}