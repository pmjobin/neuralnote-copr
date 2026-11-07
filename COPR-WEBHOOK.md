# Optional: rebuild NeuralNote COPR when GitHub `main` changes

**Do this only after the first manual SCM build succeeds and the license review
is complete.** First validate the Git checkout, SRPM source assembly, native
RPM, and standalone/VST3 runtime behaviors.

1. Open your COPR project `neuralnote`, package `neuralnote`.
2. Confirm source type **SCM**, clone URL for your public GitHub repository,
   committish **main**, source method **make srpm**, spec `neuralnote.spec`.
3. Enable **Webhook rebuild** for that package (via UI or
   `copr-cli edit-package-scm ... --webhook-rebuild on`).
4. Open COPR project's **Settings → Integrations** tab and copy the **GitHub
   webhook URL** shown there. Do not invent one or put secret values in Git.
5. In GitHub, open the packaging repository → **Settings → Webhooks → Add
   webhook**. Paste the COPR URL, use `application/json`, select **Just the
   push event**, and enable the webhook.
6. Push a harmless documentation change to a test branch / main as appropriate
   and verify the delivery in GitHub and the resulting build in COPR.

COPR's documentation for webhooks:
<https://docs.copr.fedorainfracloud.org/user_documentation.html#webhooks>.

Note: a push-triggered build might pull new submodules/assets only during the
SRPM source-builder stage. The binary builder remains offline. Do not change
upstream version/tag or SoundFont digests implicitly.

Manual rebuilding without a webhook remains available:

```bash
copr-cli build-package neuralnote --name neuralnote
```
