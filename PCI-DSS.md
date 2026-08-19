# PCI DSS scoping statement — Pay Fees By File

This document describes what data the **Pay Fees By File** Koha plugin sends to a payment
processor, what comes back, and what Koha retains. The answer to the first two is simple:
**this plugin contacts no payment processor and makes no network connection of any kind.**

It is a factual description of the plugin's behaviour at the commit named in section 5. It is not a
certification, and it does not determine any library's PCI DSS obligations. What it establishes is
whether Koha sits inside the cardholder data environment because of this plugin.

---

## 1. Summary

| Assertion | Determination |
|---|---|
| Does this plugin **accept** cardholder data (PAN, CVV/CVC/CID, expiry date, track or chip data, PIN)? | **No** |
| Does this plugin **transmit** cardholder data to any system? | **No — it transmits nothing to anyone** |
| Does this plugin **store** cardholder data? | **No** |
| Does this plugin store any **card-derived** data (card brand, truncated PAN, authorisation code)? | **No** |
| Does the patron ever enter card details into a page served by Koha? | **No** |
| Does any Koha-served page frame, embed, script, or otherwise affect a processor's card-entry page? | **No — there is no processor** |

**Determination: Koha is outside the cardholder data environment.**

This is a staff-side batch tool. A staff member uploads a CSV of payments that were **already taken
somewhere else** — it was written to import payments recorded in a PeopleSoft ERP — and the plugin
records them against patron accounts. The card transaction, if there ever was one, happened
entirely outside Koha, before the file existed.

### One term that looks like card data and is not

**The CSV column named `Cardnumber` holds the patron's library card barcode**, matched against
Koha's `borrowers.cardnumber`. It is the number printed on the plastic library card. It is not a
payment card number and not cardholder data.

---

## 2. What the plugin actually does

It is registered as a staff [tool](https://github.com/bywatersolutions/koha-plugin-pay-fees-by-file/blob/3706a8f94585b88e50e36c04e1a205324d5e71b3/Koha/Plugin/Com/ByWaterSolutions/PayFeesByFile.pm#L53). A staff member
[uploads a CSV file](https://github.com/bywatersolutions/koha-plugin-pay-fees-by-file/blob/3706a8f94585b88e50e36c04e1a205324d5e71b3/Koha/Plugin/Com/ByWaterSolutions/PayFeesByFile.pm#L102) through the browser; the plugin parses it with
[Text::CSV_XS](https://github.com/bywatersolutions/koha-plugin-pay-fees-by-file/blob/3706a8f94585b88e50e36c04e1a205324d5e71b3/Koha/Plugin/Com/ByWaterSolutions/PayFeesByFile.pm#L105) and accepts two layouts:

- [`Cardnumber` + `Amount to Pay`](https://github.com/bywatersolutions/koha-plugin-pay-fees-by-file/blob/3706a8f94585b88e50e36c04e1a205324d5e71b3/Koha/Plugin/Com/ByWaterSolutions/PayFeesByFile.pm#L118) — credits the amount to the patron's account,
  applied by Koha's own logic ([`Koha::Account->pay`](https://github.com/bywatersolutions/koha-plugin-pay-fees-by-file/blob/3706a8f94585b88e50e36c04e1a205324d5e71b3/Koha/Plugin/Com/ByWaterSolutions/PayFeesByFile.pm#L128) with no lines).
- [`Cardnumber` + `Fee ID`](https://github.com/bywatersolutions/koha-plugin-pay-fees-by-file/blob/3706a8f94585b88e50e36c04e1a205324d5e71b3/Koha/Plugin/Com/ByWaterSolutions/PayFeesByFile.pm#L141) — pays one specific accountline
  ([`->pay`](https://github.com/bywatersolutions/koha-plugin-pay-fees-by-file/blob/3706a8f94585b88e50e36c04e1a205324d5e71b3/Koha/Plugin/Com/ByWaterSolutions/PayFeesByFile.pm#L158)).

Any other layout is [rejected](https://github.com/bywatersolutions/koha-plugin-pay-fees-by-file/blob/3706a8f94585b88e50e36c04e1a205324d5e71b3/Koha/Plugin/Com/ByWaterSolutions/PayFeesByFile.pm#L171). There is no LWP, no HTTP client, no SFTP, no
socket — the plugin has no way to transmit anything off the server.

## 3. What Koha stores

- The resulting **payment accountlines**, which are ordinary Koha data. The only free text stored
  is the staff-entered comment (defaulting to "Posted in ERP Financials"), written to
  `accountlines.note`. Nothing in the code puts card data there.
- **Nothing else.** [`install`](https://github.com/bywatersolutions/koha-plugin-pay-fees-by-file/blob/3706a8f94585b88e50e36c04e1a205324d5e71b3/Koha/Plugin/Com/ByWaterSolutions/PayFeesByFile.pm#L71) and [`uninstall`](https://github.com/bywatersolutions/koha-plugin-pay-fees-by-file/blob/3706a8f94585b88e50e36c04e1a205324d5e71b3/Koha/Plugin/Com/ByWaterSolutions/PayFeesByFile.pm#L80) are stubs; there are no
  custom tables, no plugin configuration, no credentials, and no logging (every `warn` in the
  file is commented out).
- The uploaded CSV is read from CGI's request-scoped temp file and is not archived by the plugin.

## 4. Known limitations

| Item | Bearing on this document | Status |
|---|---|---|
| The plugin has no idempotency check — its own README warns that uploading the same file twice posts every payment twice. | Payment-record integrity, not card data. | Open — documented in the README |
| The `Fee ID` layout does not verify the fee belongs to the named patron. | Payment-record integrity, not card data. | Open |

## 5. What was reviewed

Reviewed at commit [`3706a8f94585b88e50e36c04e1a205324d5e71b3`](https://github.com/bywatersolutions/koha-plugin-pay-fees-by-file/commit/3706a8f94585b88e50e36c04e1a205324d5e71b3)
on 2026-08-19, covering the whole plugin — a single module,
[`PayFeesByFile.pm`](https://github.com/bywatersolutions/koha-plugin-pay-fees-by-file/blob/3706a8f94585b88e50e36c04e1a205324d5e71b3/Koha/Plugin/Com/ByWaterSolutions/PayFeesByFile.pm), and its two templates. **The review verified the absence of any
network client and any card-data field, not just their non-use.**

| Date | Commit | Reviewer | Change |
|---|---|---|---|
| 2026-08-19 | `3706a8f` | Kyle M Hall | Initial review |
