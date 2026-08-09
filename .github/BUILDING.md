# Build workflow notes

- `Build Unsigned IPA` is triggered by a normal push to `main`/`master` or by `workflow_dispatch`.
- Do not rely on a commit pushed by a workflow using the repository `GITHUB_TOKEN` to trigger another workflow. GitHub suppresses that recursive workflow trigger by design.
- Temporary CI repair workflows must not be used to publish product-source fixes to `main`; apply the verified fix with a normal repository write instead.
- A Release iPhoneOS build must pass `.app` validation and IPA ZIP verification before compatibility certification.
- The project deployment target remains iOS 15.0 and the required physical-device compatibility ceiling is iOS 17.0.
