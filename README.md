VCSCommandVlad
==============

Fork of http://code.google.com/p/vcscommand/ - http://www.vim.org/scripts/script.php?script_id=90

Changes:
 - support SCCS
 - Detect 'innermost' VCS when the given file is managed by multiple (for
    example your home in hg, project inside in git)
   - similar to (fixed) issue http://code.google.com/p/vcscommand/issues/detail?id=103
   - SVN can detect it's repository root
 - Allow reviewing/diffing of empty files
 - Abort the commit if the buffer has unsaved modifications
