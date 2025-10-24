# 🧭 EKS GitOps Autonomous Platform

## 🚀 Project Overview

This project delivers a **fully automated DevOps pipeline** that provisions, builds, and deploys applications to an **AWS EKS Kubernetes cluster** using **Terraform**, **CircleCI**, **Docker**, and **ArgoCD** — achieving **end-to-end automation** from infrastructure to application delivery.

This implementation is built to operate autonomously with **self-driving GitOps workflows**, enabling continuous provisioning, deployment, and reconciliation without manual intervention.

---

## 🧱 Core Objectives

- **Zero-Touch Deployment:** Fully automated from code commit to running workloads on EKS.  
- **Infrastructure as Code (IaC):** Declarative provisioning using modular Terraform configurations.  
- **Continuous Integration (CI):** Automated build, test, and image publishing via CircleCI.  
- **Continuous Delivery (CD):** GitOps-based application synchronization using ArgoCD.  
- **Scalability & Reproducibility:** Modularized design supporting multi-environment setups (dev/stg/prod).  

---

## ⚙️ Automation Flow

```mermaid
graph TD
A[Developer Commit Code] --> B[GitHub Repository]
B --> C[CircleCI Pipeline Trigger]
C --> D[Build & Test Application]
D --> E[Push Docker Image to Registry]
E --> F[Update Kubernetes Manifests]
F --> G[Git Push to Config Repo]
G --> H[ArgoCD Sync to EKS Cluster]
H --> I[Application Deployed & Synced Automatically]
