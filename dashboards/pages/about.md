---
sidebar: never
hide_toc: true
title: About This Project
---

<script>
  import InstallGuide from '../../components/InstallGuide.svelte';
</script>

## The Idea

I am **Salih Ugur Kimilli**, a data engineer who loves turning raw data into insights. I wanted to build a real end-to-end data engineering project using only free, open-source tools — no vendor lock-in, no cloud bills. Around the same time, I had recently moved to Denmark and realised I knew very little about Danish football.

The two things clicked together: why not build an analytics product for **Superligaen**, the Danish Premier Football League? Something I could actually use myself, and that anyone curious about Danish football could benefit from too.

That's how this project was born.

## What Was Built

A fully automated data pipeline that:

- Ingests live match data from [Sportmonks](https://www.sportmonks.com/) into a **MotherDuck** cloud data warehouse
- Transforms raw JSON through **Bronze → Silver → Gold** layers using **dbt**
- Serves analytics via this **Evidence.dev** dashboard, deployed on **Vercel**
- Runs nightly via **GitHub Actions**

## The Full Journey

The complete story — every decision, every mistake, every fix — is documented in the blog:
<div class="-mt-3">
<a href="https://saugki1773.github.io/data-engineering-blog/" target="_blank" class="inline-flex items-center gap-2 px-5 py-3 rounded-xl bg-gray-900 text-white font-semibold hover:bg-gray-700 transition-colors no-underline">
  📖 Data Engineer's Diary
</a>
</div>

## Support This Project

This dashboard is free to use and updated every day. If you find it useful, consider buying me a coffee.
<div class="-mt-3">
<a href="https://revolut.me/salihugurkimilli" target="_blank" class="inline-flex items-center gap-2 px-5 py-3 rounded-xl bg-green-600 text-white font-semibold hover:bg-green-700 transition-colors no-underline">
  Support via Revolut
</a>
</div>

## Share an Idea

Have a suggestion for the dashboard? Open an issue on GitHub — no account needed beyond a free sign-up.

<div class="-mt-3">
<a href="https://github.com/SaUgKi1773/data-engineering-demo/issues/new?template=suggestion.md" target="_blank" class="inline-flex items-center gap-2 px-5 py-3 rounded-xl bg-teal-600 text-white font-semibold hover:bg-teal-700 transition-colors no-underline">
  Share a Suggestion
</a>
</div>

## Install on Mobile

Get quick access to Superligaen Analytics directly from your phone's home screen — no app store needed.

<InstallGuide />

## Connect

<div class="mt-2">
<a href="https://www.linkedin.com/in/salih-ugur-kimilli-since1773/" target="_blank" class="inline-flex items-center gap-2 px-5 py-3 rounded-xl bg-blue-600 text-white font-semibold hover:bg-blue-700 transition-colors no-underline">
  LinkedIn — Salih Ugur Kimilli
</a>
</div>
