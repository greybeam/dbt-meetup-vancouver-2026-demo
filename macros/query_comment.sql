-- macros/query_comment.sql

{% macro query_comment(node) %}
    {% set comment = {
        "app": "dbt",
        "dbt_version": dbt_version,
        "project_name": project_name,
        "profile_name": target.profile_name,
        "target_name": target.name,
        "invocation_id": invocation_id
    } %}

    {% if node %}
        {% do comment.update({
            "node_name": node.name,
            "node_id": node.unique_id,
            "resource_type": node.resource_type
        }) %}
    {% endif %}

    {{ return(tojson(comment)) }}
{% endmacro %}