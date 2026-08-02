;;; herdr-tuicr-tests.el --- Tests for herdr-tuicr  -*- lexical-binding:t -*-

;; Copyright (C) 2026 Roman Gonzalez

;; SPDX-License-Identifier: GPL-3.0-or-later

;; This file is free software: you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by the
;; Free Software Foundation, either version 3 of the License, or (at your
;; option) any later version.
;;
;; This file is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
;; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
;; for more details.
;;
;; You should have received a copy of the GNU General Public License along
;; with this file.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Two halves, tested two ways.  The panel reads the session tree, so it
;; is driven from a hand-written snapshot.  The lifecycle lives in the
;; herdr-review script, so it is driven for real against the herdr in
;; test/bin, which keeps a session in files.

;; What that stub is for is the one state a live server cannot be asked
;; for: two callers claiming one workspace at the same instant.  Its
;; on-claim hook injects a competing claim at the moment the script makes
;; its own, which is the race the one-review-per-workspace rule turns on.

;;; Code:

(require 'cl-lib)
(require 'ert)

(require 'herdr-tuicr)

;;; Fixtures

(defconst herdr-tuicr-tests--directory
  (file-name-directory (or load-file-name buffer-file-name))
  "Where this file sits, which is how it finds the script and the stub.")

(defmacro herdr-tuicr-with-snapshot (snapshot &rest body)
  "Evaluate BODY with the session tree set to SNAPSHOT.
SNAPSHOT is a plist in the shape herdr answers `session.snapshot'
with.  The tree is restored afterwards, so a test cannot leak into the
next one.

herdr.el has a fixture of its own that does this, but its test files
are not part of what it installs, so reaching for one would make this
suite depend on a checkout rather than on a package."
  (declare (indent 1) (debug t))
  `(let ((herdr-session--snapshot
          (json-parse-string (json-serialize ,snapshot)
                             :false-object nil :null-object nil)))
     ,@body))

(defvar herdr-tuicr-tests--state nil
  "Directory the stub herdr keeps the current test's session in.")

(defmacro herdr-tuicr-with-stub-session (&rest body)
  "Evaluate BODY against a stub herdr holding one workspace.
The workspace is w1, its root pane w1:p1, and it has no review.  The
session directory is left behind when a test fails, so that what the
script did to it can be read afterwards."
  (declare (indent 0) (debug t))
  `(let* ((herdr-tuicr-tests--state (make-temp-file "herdr-tuicr-" t))
          (bin (expand-file-name "bin" herdr-tuicr-tests--directory))
          (herdr-tuicr-program
           (expand-file-name "../bin/herdr-review"
                             herdr-tuicr-tests--directory))
          (process-environment
           (cons (concat "HERDR_STUB_STATE=" herdr-tuicr-tests--state)
                 (cons (concat "PATH=" bin path-separator (getenv "PATH"))
                       process-environment))))
     (herdr-tuicr-tests--write "panes" "w1:p1 w1:t1 w1 /repo")
     (herdr-tuicr-tests--write "workspaces" "w1 w1:t1 project")
     (prog1 (progn ,@body)
       (delete-directory herdr-tuicr-tests--state t))))

(defun herdr-tuicr-tests--write (name &rest lines)
  "Write LINES to the stub session's file called NAME."
  (with-temp-file (expand-file-name name herdr-tuicr-tests--state)
    (dolist (line lines)
      (insert line "\n"))))

(defun herdr-tuicr-tests--read (name)
  "Return the lines of the stub session's file called NAME."
  (let ((file (expand-file-name name herdr-tuicr-tests--state)))
    (when (file-exists-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (split-string (buffer-string) "\n" t)))))

(defun herdr-tuicr-tests--claim-hook (pane)
  "Make the stub claim PANE for someone else the moment the script claims.
This is the losing half of the race: another caller got its claim in
between the script's check and the script's own claim."
  (herdr-tuicr-tests--write
   "on-claim"
   "#!/usr/bin/env bash"
   (format "grep -qxF %s \"$HERDR_STUB_STATE/claims\" || \
printf '%s\\n' >> \"$HERDR_STUB_STATE/claims\"" pane pane))
  (set-file-modes (expand-file-name "on-claim" herdr-tuicr-tests--state)
                  #o755))

(defun herdr-tuicr-tests--review (&rest arguments)
  "Run the herdr-review script with ARGUMENTS and return its JSON reply."
  (with-temp-buffer
    (let ((status (apply #'call-process herdr-tuicr-program nil t nil
                         arguments)))
      (unless (eq status 0)
        (error "The herdr-review script failed: %s" (buffer-string)))
      (goto-char (point-min))
      (json-parse-buffer :object-type 'alist))))

(defun herdr-tuicr-tests--agent (pane kind status &optional workspace)
  "Return an agent plist in PANE, of KIND, in STATUS, in WORKSPACE."
  (list :pane_id pane :workspace_id (or workspace "w1") :tab_id "w1:t1"
        :agent kind :agent_status status))

(defun herdr-tuicr-tests--record (plist)
  "Return PLIST as the hash table herdr would have answered with.
The panel reads records with `gethash', so a plist would pass tests
that a real reply fails."
  (json-parse-string (json-serialize plist)))

;;; Opening A Review

(ert-deftest herdr-tuicr-open:puts-the-review-in-a-tab-of-its-own ()
  "A review gets a tab, claims it, and starts there.
Claiming before the pane runs anything is what makes the workspace's
one review slot taken from the moment the tab appears."
  (herdr-tuicr-with-stub-session
    (let ((reply (herdr-tuicr-tests--review "open" "--workspace" "w1")))
      (should (equal (alist-get 'pane_id reply) "w1:p2"))
      (should (eq (alist-get 'reused reply) :false))
      (should (equal (herdr-tuicr-tests--read "claims") '("w1:p2")))
      (let ((log (herdr-tuicr-tests--read "log")))
        (should (eql (length log) 2))
        (should (equal (car log) "report-agent w1:p2"))
        (should (string-prefix-p "pane run w1:p2" (cadr log)))))))

(ert-deftest herdr-tuicr-open:goes-to-the-review-already-open ()
  "A workspace holds one review, so a second request is a jump.
Two open reviews of one checkout is more than an operator can hold,
and the panel shows a row per workspace on the strength of it."
  (herdr-tuicr-with-stub-session
    (herdr-tuicr-tests--review "open" "--workspace" "w1")
    (let ((reply (herdr-tuicr-tests--review "open" "--workspace" "w1")))
      (should (equal (alist-get 'pane_id reply) "w1:p2"))
      (should (eq (alist-get 'reused reply) t))
      (should (equal (herdr-tuicr-tests--read "claims") '("w1:p2")))
      (should (member "agent focus w1:p2" (herdr-tuicr-tests--read "log"))))))

(ert-deftest herdr-tuicr-open:stands-down-when-it-loses-the-race ()
  "Two callers at once leave one review, not two.
The check cannot be trusted, because another caller can pass it in the
same instant, so the claim is verified after it is made and everyone
but the oldest claim gives its tab back."
  (herdr-tuicr-with-stub-session
    (herdr-tuicr-tests--claim-hook "w1:p1")
    (let ((reply (herdr-tuicr-tests--review "open" "--workspace" "w1")))
      (should (equal (alist-get 'pane_id reply) "w1:p1"))
      (should (eq (alist-get 'reused reply) t))
      (should (equal (herdr-tuicr-tests--read "claims") '("w1:p1")))
      (should (equal (herdr-tuicr-tests--read "panes")
                     '("w1:p1 w1:t1 w1 /repo")))
      (should (member "tab close w1:t2" (herdr-tuicr-tests--read "log"))))))

(ert-deftest herdr-tuicr-open:hands-tuicr-its-own-arguments ()
  "What follows -- is tuicr's, so a review is not always the worktree."
  (herdr-tuicr-with-stub-session
    (herdr-tuicr-tests--review "open" "--workspace" "w1"
                               "--" "--revisions" "HEAD~3..HEAD")
    (should (string-match-p "revisions"
                            (car (last (herdr-tuicr-tests--read "log")))))))

;;; Ending A Review

(ert-deftest herdr-tuicr-close:gives-the-pane-and-the-tab-back ()
  "Ending a review frees the workspace to hold the next one."
  (herdr-tuicr-with-stub-session
    (herdr-tuicr-tests--review "open" "--workspace" "w1")
    (let ((reply (herdr-tuicr-tests--review "close" "--workspace" "w1")))
      (should (eq (alist-get 'closed reply) t))
      (should (null (herdr-tuicr-tests--read "claims")))
      (should (member "release-agent w1:p2" (herdr-tuicr-tests--read "log"))))))

(ert-deftest herdr-tuicr-close:says-so-when-there-is-nothing-to-close ()
  "Closing a workspace with no review is not an error.
A caller cleaning up after an operator who walked away cannot know
whether they quit the TUI first."
  (herdr-tuicr-with-stub-session
    (let ((reply (herdr-tuicr-tests--review "close" "--workspace" "w1")))
      (should (eq (alist-get 'closed reply) :false)))))

(ert-deftest herdr-tuicr-status:answers-empty-when-nothing-is-open ()
  "An empty object is how a caller learns the operator is done."
  (herdr-tuicr-with-stub-session
    (should (null (herdr-tuicr-tests--review "status" "--workspace" "w1")))
    (herdr-tuicr-tests--review "open" "--workspace" "w1")
    (should (equal (alist-get 'agent (herdr-tuicr-tests--review
                                      "status" "--workspace" "w1"))
                   "tuicr"))))

;;; Listing Reviews

(ert-deftest herdr-tuicr-reviews-list:lists-reviews-and-nothing-else ()
  "A coding agent is not a review, whatever state it is in."
  (herdr-tuicr-with-snapshot
      (list :agents (vector (herdr-tuicr-tests--agent "w1:p1" "claude" "blocked")
                            (herdr-tuicr-tests--agent "w1:p2" "tuicr" "blocked")
                            (herdr-tuicr-tests--agent "w1:p3" "codex" "idle")))
    (should (equal (mapcar (lambda (review) (gethash "pane_id" review))
                           (herdr-tuicr-reviews-list))
                   '("w1:p2")))))

(ert-deftest herdr-tuicr-reviews-list:puts-attention-first ()
  "A review waiting for the operator sorts above one that is not."
  (herdr-tuicr-with-snapshot
      (list :agents (vector (herdr-tuicr-tests--agent "w1:p1" "tuicr" "idle" "w1")
                            (herdr-tuicr-tests--agent "w2:p1" "tuicr" "blocked" "w2")))
    (should (equal (mapcar (lambda (review) (gethash "pane_id" review))
                           (herdr-tuicr-reviews-list))
                   '("w2:p1" "w1:p1")))))

;;; Drawing A Row

(ert-deftest herdr-tuicr--label:names-the-workspace-under-review ()
  "One review per workspace makes the workspace what the row is about."
  (herdr-tuicr-with-snapshot
      (list :workspaces (vector (list :workspace_id "w1" :label "project")))
    (should (equal (herdr-tuicr--label
                    (herdr-tuicr-tests--record '(:workspace_id "w1")))
                   "project"))))

(ert-deftest herdr-tuicr--label:falls-back-to-the-workspace-id ()
  "A workspace herdr has not described yet still gets a row."
  (herdr-tuicr-with-snapshot (list :workspaces (vector))
    (should (equal (herdr-tuicr--label
                    (herdr-tuicr-tests--record '(:workspace_id "w9")))
                   "w9"))))

(ert-deftest herdr-tuicr--summary:reads-the-metadata-token ()
  "What is waiting comes from herdr, not from reading the terminal."
  (should (equal (herdr-tuicr--summary
                  (herdr-tuicr-tests--record
                   '(:tokens (:summary "3 files to review"))))
                 "3 files to review"))
  (should (null (herdr-tuicr--summary
                 (herdr-tuicr-tests--record '(:pane_id "w1:p1"))))))

;;; Finding What To Review

(ert-deftest herdr-tuicr--workspace-at-point:asks-the-panel-for-a-pane ()
  "Every panel answers with a pane, and the pane names the workspace.
Read off the section instead, and this would have to know how each
panel draws its rows."
  (herdr-tuicr-with-snapshot
      (list :panes (vector (list :pane_id "w1:p1" :workspace_id "w1")))
    (with-temp-buffer
      (setq-local herdr-panel-pane-function (lambda () "w1:p1"))
      (should (equal (herdr-tuicr--workspace-at-point) "w1")))))

(ert-deftest herdr-tuicr--workspace-at-point:answers-nothing-off-a-row ()
  "A panel signals when point is on no row; that is not an answer."
  (herdr-tuicr-with-snapshot (list :panes (vector))
    (with-temp-buffer
      (setq-local herdr-panel-pane-function
                  (lambda () (user-error "No review at point")))
      (should (null (herdr-tuicr--workspace-at-point))))
    (with-temp-buffer
      (should (null (herdr-tuicr--workspace-at-point))))))

;;; Reaching The Script

(ert-deftest herdr-tuicr--run:refuses-a-script-it-cannot-find ()
  "A missing script is said once, not discovered as a process error."
  (let ((herdr-tuicr-program "herdr-review-that-is-not-installed"))
    (should-error (herdr-tuicr--run "open") :type 'user-error)))

(ert-deftest herdr-tuicr--run:reports-what-the-script-said ()
  "The script's own complaint reaches the user.
A review that silently did not open looks exactly like one nobody
asked for."
  (let ((herdr-tuicr-program (expand-file-name "bin/herdr"
                                               herdr-tuicr-tests--directory))
        (process-environment (cons "HERDR_STUB_STATE=" process-environment)))
    (should-error (herdr-tuicr--run "open") :type 'user-error)))

;;; Fitting Into herdr

(ert-deftest herdr-tuicr:takes-reviews-out-of-the-agents-panel ()
  "Loading this package is what hides a review from the agents panel.
Listed in both, a review would be counted twice by anything reducing
over what wants attention."
  (should (member herdr-tuicr-agent herdr-agents-hidden-kinds)))

;;; _
(provide 'herdr-tuicr-tests)
;; Local Variables:
;; indent-tabs-mode: nil
;; End:
;;; herdr-tuicr-tests.el ends here
