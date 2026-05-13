# Platform Specialists

Domain-specific patterns for major platforms.

## Salesforce

| Area | Pattern |
|------|---------|
| Apex | Bulkified triggers, governor limit awareness |
| LWC | Lightning Web Components with reactive properties |
| SOQL | Selective queries, relationship queries |
| Testing | @isTest classes, Test.startTest()/stopTest() |
| Limits | 100 SOQL queries/transaction, 150 DML statements |

## Shopify

| Area | Pattern |
|------|---------|
| Liquid | Template language for themes |
| Storefront API | GraphQL for headless commerce |
| Apps | Shopify CLI, App Bridge, Polaris UI |
| Checkout | Checkout Extensions for custom logic |
| Webhooks | Mandatory HMAC verification |

## WordPress

| Area | Pattern |
|------|---------|
| Themes | Block themes with theme.json |
| Plugins | Hooks (actions/filters), singleton pattern |
| Gutenberg | Custom blocks with React + @wordpress/scripts |
| WooCommerce | Custom product types, payment gateways |
| Security | Nonce verification, capability checks, data sanitization |

## Atlassian (MCP Integration)

| Area | Pattern |
|------|---------|
| JQL | Jira Query Language for issue search |
| CQL | Confluence Query Language for content search |
| REST API | OAuth 2.0 authentication |
| Automation | Jira automation rules, webhooks |
