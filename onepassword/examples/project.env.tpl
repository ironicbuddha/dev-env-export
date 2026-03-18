# Example template for project-local secrets rendered via `op inject`
# or loaded directly with `op run --env-file`.
#
# Adjust vault, item, and field names to match your own 1Password structure.

OPENAI_API_KEY=op://${VAULT:-Private}/openai - api credential/api key
ANTHROPIC_API_KEY=op://${VAULT:-Private}/anthropic - api credential/api key
FIRECRAWL_API_KEY=op://${VAULT:-Private}/firecrawl - api credential/api key
GITHUB_TOKEN=op://${VAULT:-Private}/github - personal access token/personal access token
AWS_ACCESS_KEY_ID=op://${VAULT:-Private}/aws - main account/access key id
AWS_SECRET_ACCESS_KEY=op://${VAULT:-Private}/aws - main account/secret access key
AWS_DEFAULT_REGION=af-south-1
