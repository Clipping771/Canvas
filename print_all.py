import os

docs = [
    'docs/strategy/00_project_governance.md',
    'docs/strategy/01_prd.md',
    'docs/strategy/02_user_personas.md',
    'docs/strategy/03_domain_model.md',
    'docs/strategy/04_business_model.md',
    'docs/agent/01_agent_rules.md',
    'docs/agent/02_coding_standards.md',
    'docs/agent/03_definition_of_done.md',
    'docs/agent/04_ports_and_adapters.md',
    'docs/agent/05_architecture_contracts.md',
    'docs/agent/prompt_library/README.md',
    'docs/agent/06_testing_strategy.md',
    'docs/strategy/05_curriculum_architecture.md',
    'docs/strategy/06_student_teacher_workflows.md',
    'docs/strategy/07_system_architecture.md',
    'docs/strategy/08_ai_architecture.md',
    'docs/strategy/09_data_and_privacy.md',
    'docs/agent/adr_log/0000_template.md',
    'docs/strategy/assumption_register.md',
    'docs/strategy/validation_results.md',
    'docs/strategy/roadmap_long_term.md'
]

with open('all_docs.txt', 'w', encoding='utf-8') as out:
    for doc in docs:
        out.write(f'\\n\\n### {doc}\\n\\n')
        try:
            with open(doc, 'r', encoding='utf-8') as f:
                out.write(f.read())
        except FileNotFoundError:
            out.write('FILE NOT FOUND')
