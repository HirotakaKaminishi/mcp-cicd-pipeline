/**
 * GitHub Integration for Vibe-Kanban
 * Handles repository synchronization, PR management, and CI/CD integration
 */

const axios = require('axios');
const crypto = require('crypto');

class GitHubIntegration {
  constructor(options = {}) {
    this.token = options.token || process.env.GITHUB_TOKEN;
    this.webhookSecret = options.webhookSecret || process.env.GITHUB_WEBHOOK_SECRET;
    this.baseUrl = options.baseUrl || 'https://api.github.com';
    this.owner = options.owner || 'HirotakaKaminishi';
    this.repo = options.repo || 'mcp-cicd-pipeline';
    
    this.axiosInstance = axios.create({
      baseURL: this.baseUrl,
      headers: {
        'Authorization': `token ${this.token}`,
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'Vibe-Kanban-Integration/1.0.0'
      },
      timeout: 30000
    });
  }

  /**
   * Create a new branch for AI agent work
   */
  async createBranch(taskId, baseBranch = 'main') {
    try {
      const branchName = `vibe-kanban/task-${taskId}`;
      
      // Get base branch SHA
      const baseRef = await this.axiosInstance.get(`/repos/${this.owner}/${this.repo}/git/ref/heads/${baseBranch}`);
      const baseSha = baseRef.data.object.sha;

      // Create new branch
      await this.axiosInstance.post(`/repos/${this.owner}/${this.repo}/git/refs`, {
        ref: `refs/heads/${branchName}`,
        sha: baseSha
      });

      console.log(`Created branch: ${branchName} from ${baseBranch}`);
      
      return {
        success: true,
        branchName,
        baseBranch,
        sha: baseSha
      };
    } catch (error) {
      if (error.response?.status === 422) {
        // Branch already exists
        return {
          success: true,
          branchName: `vibe-kanban/task-${taskId}`,
          message: 'Branch already exists'
        };
      }
      
      console.error('Failed to create branch:', error.message);
      throw new Error(`Failed to create branch: ${error.message}`);
    }
  }

  /**
   * Create a pull request for completed task
   */
  async createPullRequest(taskData) {
    try {
      const branchName = `vibe-kanban/task-${taskData.id}`;
      const title = `[Vibe-Kanban] ${taskData.title}`;
      const body = this.generatePRBody(taskData);

      const response = await this.axiosInstance.post(`/repos/${this.owner}/${this.repo}/pulls`, {
        title,
        body,
        head: branchName,
        base: 'main',
        draft: taskData.requireReview !== false
      });

      console.log(`Created PR #${response.data.number}: ${title}`);
      
      return {
        success: true,
        prNumber: response.data.number,
        url: response.data.html_url,
        isDraft: response.data.draft
      };
    } catch (error) {
      console.error('Failed to create PR:', error.message);
      throw new Error(`Failed to create PR: ${error.message}`);
    }
  }

  /**
   * Generate PR body based on task data
   */
  generatePRBody(taskData) {
    return `## 🤖 AI Agent Task Completion

### Task Details
- **Task ID**: ${taskData.id}
- **Assigned Agent**: ${taskData.assignedAgent}
- **Category**: ${taskData.category}
- **Priority**: ${taskData.priority}

### Description
${taskData.description}

### Changes Made
${taskData.changesSummary || 'Automated changes by AI agent'}

### Quality Checklist
- [${taskData.testsRun ? 'x' : ' '}] Tests executed and passing
- [${taskData.lintChecked ? 'x' : ' '}] Code linting completed
- [${taskData.securityChecked ? 'x' : ' '}] Security review completed
- [${taskData.requireReview ? 'x' : ' '}] Human review required

### AI Agent Metadata
- **Processing Time**: ${taskData.processingTime || 'N/A'}
- **Confidence Score**: ${taskData.confidenceScore || 'N/A'}
- **Automated**: ${taskData.fullyAutomated ? 'Yes' : 'No'}

---
*🤖 This PR was automatically created by Vibe-Kanban AI Agent: ${taskData.assignedAgent}*
*Generated at: ${new Date().toISOString()}*

Co-Authored-By: Claude <noreply@anthropic.com>`;
  }

  /**
   * Handle GitHub webhook events
   */
  async handleWebhook(event, payload, signature) {
    try {
      // Validate webhook signature
      if (!this.validateWebhookSignature(payload, signature)) {
        throw new Error('Invalid webhook signature');
      }

      console.log(`Processing GitHub webhook: ${event}`);

      switch (event) {
        case 'pull_request':
          return await this.handlePullRequestEvent(payload);
        case 'push':
          return await this.handlePushEvent(payload);
        case 'workflow_run':
          return await this.handleWorkflowRunEvent(payload);
        case 'check_run':
          return await this.handleCheckRunEvent(payload);
        default:
          console.log(`Unhandled webhook event: ${event}`);
          return { success: true, message: 'Event ignored' };
      }
    } catch (error) {
      console.error('Webhook handling error:', error);
      throw error;
    }
  }

  /**
   * Validate GitHub webhook signature
   */
  validateWebhookSignature(payload, signature) {
    if (!this.webhookSecret || !signature) {
      return false;
    }

    const expectedSignature = `sha256=${crypto
      .createHmac('sha256', this.webhookSecret)
      .update(payload)
      .digest('hex')}`;

    return crypto.timingSafeEqual(
      Buffer.from(signature),
      Buffer.from(expectedSignature)
    );
  }

  /**
   * Handle pull request events
   */
  async handlePullRequestEvent(payload) {
    const { action, pull_request } = payload;
    const prNumber = pull_request.number;
    
    console.log(`PR #${prNumber} ${action}`);

    // Check if this is a Vibe-Kanban PR
    const isVibeKanbanPR = pull_request.head.ref.startsWith('vibe-kanban/task-');
    
    if (!isVibeKanbanPR) {
      return { success: true, message: 'Not a Vibe-Kanban PR' };
    }

    const taskId = pull_request.head.ref.replace('vibe-kanban/task-', '');

    switch (action) {
      case 'opened':
        return await this.onPROpened(taskId, pull_request);
      case 'closed':
        return await this.onPRClosed(taskId, pull_request);
      case 'review_requested':
        return await this.onPRReviewRequested(taskId, pull_request);
      default:
        return { success: true, message: `PR action ${action} handled` };
    }
  }

  /**
   * Handle PR opened event
   */
  async onPROpened(taskId, pullRequest) {
    try {
      // Update Vibe-Kanban task status
      await this.updateVibeKanbanTaskStatus(taskId, 'review', {
        prNumber: pullRequest.number,
        prUrl: pullRequest.html_url,
        status: 'under_review'
      });

      // Add automated checks
      if (process.env.AUTO_ADD_PR_CHECKS === 'true') {
        await this.addAutomatedChecks(pullRequest.number);
      }

      return {
        success: true,
        message: `Task ${taskId} moved to review status`
      };
    } catch (error) {
      console.error(`Failed to handle PR opened for task ${taskId}:`, error);
      throw error;
    }
  }

  /**
   * Handle PR closed event
   */
  async onPRClosed(taskId, pullRequest) {
    const status = pullRequest.merged ? 'done' : 'todo';
    const statusMessage = pullRequest.merged ? 'completed and merged' : 'closed without merge';

    await this.updateVibeKanbanTaskStatus(taskId, status, {
      prNumber: pullRequest.number,
      merged: pullRequest.merged,
      mergedAt: pullRequest.merged_at
    });

    return {
      success: true,
      message: `Task ${taskId} ${statusMessage}`
    };
  }

  /**
   * Update Vibe-Kanban task status via API
   */
  async updateVibeKanbanTaskStatus(taskId, status, additionalData = {}) {
    try {
      const vibeKanbanUrl = process.env.VIBE_KANBAN_URL || 'http://vibe-kanban:3000';
      
      await axios.patch(`${vibeKanbanUrl}/api/kanban/tasks/${taskId}`, {
        status,
        lastUpdated: new Date().toISOString(),
        updatedBy: 'github-integration',
        githubData: additionalData
      }, {
        timeout: 5000,
        headers: {
          'Content-Type': 'application/json',
          'x-integration-source': 'github'
        }
      });

      console.log(`Updated Vibe-Kanban task ${taskId} to status: ${status}`);
    } catch (error) {
      console.error(`Failed to update Vibe-Kanban task ${taskId}:`, error.message);
      // Don't throw - this shouldn't break the GitHub webhook processing
    }
  }

  /**
   * Add automated PR checks
   */
  async addAutomatedChecks(prNumber) {
    try {
      // Add assignees if specified
      if (process.env.DEFAULT_PR_REVIEWERS) {
        const reviewers = process.env.DEFAULT_PR_REVIEWERS.split(',');
        await this.axiosInstance.post(`/repos/${this.owner}/${this.repo}/pulls/${prNumber}/requested_reviewers`, {
          reviewers
        });
      }

      // Add labels
      const labels = ['ai-generated', 'vibe-kanban', 'needs-review'];
      await this.axiosInstance.post(`/repos/${this.owner}/${this.repo}/issues/${prNumber}/labels`, {
        labels
      });

      console.log(`Added automated checks to PR #${prNumber}`);
    } catch (error) {
      console.error(`Failed to add automated checks to PR #${prNumber}:`, error.message);
    }
  }

  /**
   * Handle workflow run events
   */
  async handleWorkflowRunEvent(payload) {
    const { action, workflow_run } = payload;
    
    if (action !== 'completed') {
      return { success: true, message: 'Workflow not completed yet' };
    }

    // Check if this affects a Vibe-Kanban branch
    const branchName = workflow_run.head_branch;
    if (!branchName.startsWith('vibe-kanban/task-')) {
      return { success: true, message: 'Not a Vibe-Kanban workflow' };
    }

    const taskId = branchName.replace('vibe-kanban/task-', '');
    const success = workflow_run.conclusion === 'success';

    console.log(`Workflow for task ${taskId} ${workflow_run.conclusion}`);

    // Update task with CI results
    await this.updateVibeKanbanTaskStatus(taskId, success ? 'review' : 'blocked', {
      ciStatus: workflow_run.conclusion,
      ciUrl: workflow_run.html_url,
      workflowId: workflow_run.id
    });

    return {
      success: true,
      message: `Task ${taskId} CI status updated: ${workflow_run.conclusion}`
    };
  }

  /**
   * Handle check run events
   */
  async handleCheckRunEvent(payload) {
    const { action, check_run } = payload;
    
    if (action !== 'completed') {
      return { success: true, message: 'Check not completed yet' };
    }

    console.log(`Check run ${check_run.name}: ${check_run.conclusion}`);
    
    return { success: true, message: 'Check run processed' };
  }

  /**
   * Get repository information
   */
  async getRepositoryInfo() {
    try {
      const response = await this.axiosInstance.get(`/repos/${this.owner}/${this.repo}`);
      return {
        success: true,
        repository: response.data
      };
    } catch (error) {
      console.error('Failed to get repository info:', error.message);
      throw error;
    }
  }

  /**
   * List open pull requests
   */
  async listOpenPullRequests() {
    try {
      const response = await this.axiosInstance.get(`/repos/${this.owner}/${this.repo}/pulls`, {
        params: { state: 'open' }
      });

      const vibeKanbanPRs = response.data.filter(pr => 
        pr.head.ref.startsWith('vibe-kanban/task-')
      );

      return {
        success: true,
        pullRequests: vibeKanbanPRs,
        total: vibeKanbanPRs.length
      };
    } catch (error) {
      console.error('Failed to list pull requests:', error.message);
      throw error;
    }
  }
}

module.exports = GitHubIntegration;