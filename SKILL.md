---
name: wow-api-check
description: Use before calling any WoW API function or event. Verifies it exists for WoW Forever and records the result.
---
1. Search the Warcraft Wiki for the function/event and its availability.
2. If unconfirmed, generate an in-game test: `/run print(type(FunctionName))`.
3. Record verified APIs in docs/api-verified.md with date.
4. Never use an unverified API.