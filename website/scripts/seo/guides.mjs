/**
 * Guide content. Each guide becomes /guides/<slug> (public/guides/<slug>.html).
 *
 * Writing rules, so the pages keep working for search and AI answers:
 *   - `answer` is the direct answer to the page's question. Lead with it.
 *   - Headings are the questions and tasks people actually type.
 *   - `faq` is rendered on the page AND emitted as FAQPage structured data
 *     from the same text, so the two can never disagree.
 *   - Only claim what the shipping Mac app does (see FEATURES in site.mjs).
 *
 * After editing, run `npm run seo` (it also runs as part of `npm run build`).
 */

const ICLEARER_FREE_NOTE =
  "Scanning is free on every Mac and the free plan includes 500 MB of cleanup. Unlimited cleanup starts at $29.99 per year for one Mac, with a 14-day money-back guarantee.";

export const GUIDES = [
  {
    slug: "mac-storage-full",
    featured: true,
    title: "Mac Storage Full? How to Free Up Space Safely",
    h1: "Mac storage full? How to free up space safely",
    card: "Mac storage full: what to do",
    description:
      "Startup disk almost full? See what is using your Mac’s storage, then clear caches, System Data, large files and developer junk safely, step by step.",
    answer: `<p>If your Mac says <b>“Your disk is almost full”</b>, open <b>System Settings → General → Storage</b> to see what is using the space. Then remove what is safe first: empty the Trash, delete old downloads and installers, clear app caches and logs, remove old iPhone backups, and delete large files you no longer need. Developers usually get the most space back from Xcode, npm, Homebrew and Docker caches. Try to keep at least 10–15% of the disk free.</p>`,
    toc: [
      ["check", "See what is using your storage"],
      ["quick-wins", "Quick wins that take five minutes"],
      ["caches", "Clear app caches and logs"],
      ["system-data", "Shrink System Data"],
      ["large-files", "Find large and old files"],
      ["apps", "Remove apps you do not use"],
      ["developers", "If you write code"],
      ["do-not-delete", "What you should not delete"],
    ],
    body: `
<h2 id="check">1. See what is using your storage</h2>
<p>Before you delete anything, look at the breakdown macOS gives you.</p>
<ol>
  <li>Open the Apple menu and choose <b>System Settings</b>.</li>
  <li>Click <b>General</b>, then <b>Storage</b>.</li>
  <li>Wait for the coloured bar to finish calculating, then click the <b>i</b> button next to a category to see what is inside it.</li>
</ol>
<p>On macOS 12 Monterey or earlier, choose Apple menu → About This Mac → Storage → Manage instead.</p>

<h2 id="quick-wins">2. Quick wins that take five minutes</h2>
<ul>
  <li><b>Empty the Trash.</b> Files in the Trash still take up space. Right-click the Trash in the Dock and choose Empty Trash.</li>
  <li><b>Clear out Downloads.</b> Open Downloads in Finder, switch to List view and sort by Size. Old installers (<code>.dmg</code> and <code>.pkg</code> files) and zip archives are usually safe to delete once the app is installed.</li>
  <li><b>Use the built-in recommendations.</b> In Storage settings, turn on Empty Trash Automatically and Optimize Storage. Store in iCloud helps too if you pay for iCloud space.</li>
  <li><b>Restart your Mac.</b> A restart clears temporary files and the swap files macOS creates when memory runs low.</li>
</ul>

<h2 id="caches">3. Clear app caches and logs</h2>
<p>Apps keep caches so they load faster, and those caches can grow to many gigabytes. They are safe to remove because apps rebuild them.</p>
<ol>
  <li>Quit the apps you have open.</li>
  <li>In Finder, press <kbd>Shift</kbd> <kbd>Command</kbd> <kbd>G</kbd> and enter <code>~/Library/Caches</code>.</li>
  <li>Press <kbd>Command</kbd> <kbd>J</kbd> and tick <b>Calculate All Sizes</b> so Finder shows how big each folder is.</li>
  <li>Move the contents of the largest folders to the Trash.</li>
  <li>Repeat for <code>~/Library/Logs</code>, then empty the Trash.</li>
</ol>
<p>The full walkthrough, including browser caches, is in <a href="/guides/clear-cache-mac">how to clear cache on Mac</a>.</p>

<h2 id="system-data">4. Shrink System Data</h2>
<p>System Data is the grey catch-all in the storage bar. It holds caches, logs, Time Machine local snapshots, swap files and files left behind by apps. You cannot delete the category in one go, but you can shrink what is inside it. See <a href="/guides/clear-system-data-mac">how to clear System Data on Mac</a>.</p>

<h2 id="large-files">5. Find large and old files</h2>
<p>A few forgotten files often hold more space than every cache combined: old videos, virtual machines, disk images and archives. In Storage settings, click the <b>i</b> next to Documents and open <b>Large Files</b>. There are two more methods in <a href="/guides/find-large-files-mac">how to find large files on Mac</a>.</p>

<h2 id="apps">6. Remove apps you do not use</h2>
<p>Dragging an app to the Trash removes the app but leaves its support files, caches and preferences in your Library folder. <a href="/guides/uninstall-apps-mac">How to uninstall apps on Mac completely</a> lists where those leftovers live.</p>

<h2 id="developers">7. If you write code</h2>
<p>Build caches and package downloads are usually the biggest space users on a developer’s Mac. These commands are safe because the tools download or rebuild what they need:</p>
<pre><code>rm -rf ~/Library/Developer/Xcode/DerivedData
npm cache clean --force
brew cleanup --prune=all
pip cache purge
docker system prune</code></pre>
<p>More tools and what each command removes: <a href="/guides/free-up-disk-space-mac-developers">free up disk space on a Mac for developers</a>.</p>

<h2 id="do-not-delete">What you should not delete</h2>
<div class="g-tbl"><table>
  <tr><th>Leave this alone</th><th>Why</th></tr>
  <tr><td><code>/System</code> and <code>/usr</code></td><td>These are macOS itself.</td></tr>
  <tr><td><code>~/Library/Keychains</code></td><td>Your saved passwords and certificates.</td></tr>
  <tr><td><code>~/Library/Application Support</code> folders for apps you still use</td><td>This is app data, not cache. Deleting it can erase settings, projects or chat history.</td></tr>
  <tr><td><code>~/.ssh</code>, <code>.env</code> files and <code>.git</code> folders</td><td>Keys, secrets and your project history.</td></tr>
  <tr><td>Your only iPhone or iPad backup</td><td>It cannot be rebuilt. Keep the most recent one.</td></tr>
</table></div>
`,
    cta: {
      heading: "The faster way: scan once with iClearer",
      text: `<p>iClearer does every step on this page in one scan. It lists caches, logs, leftovers, developer files and large files with their sizes, labels each one <b>Safe</b> or <b>Ask first</b>, and moves what you choose to the Trash so you can undo it. Keychain, accounts, tokens and git repositories can never be selected.</p>`,
    },
    faq: [
      {
        q: "Why is my Mac storage full when I have nothing on it?",
        a: "Most of the space is in places Finder hides by default. The Library folder holds app caches, logs and files left behind by apps you deleted, and System Data holds Time Machine local snapshots and swap files. Open System Settings → General → Storage to see the breakdown.",
      },
      {
        q: "How much free space should a Mac have?",
        a: "A common rule of thumb is to keep at least 10–15% of the disk free. macOS needs room for swap files, updates and local snapshots, and major macOS upgrades often need 20 GB or more of free space to install.",
      },
      {
        q: "Does emptying the Trash free up space on a Mac?",
        a: "Yes. Files in the Trash still count against your storage until you empty it. If the free space does not change straight away, a Time Machine local snapshot may still be holding the files; macOS removes those snapshots automatically when it needs the space.",
      },
      {
        q: "What is the fastest way to free up space on a Mac?",
        a: "Empty the Trash, delete old installers from Downloads, and clear the largest folders in ~/Library/Caches. A cleaner app such as iClearer does the same in one scan and shows the size of each item before anything is removed.",
      },
      {
        q: "Is it safe to use a Mac cleaner app?",
        a: "It depends on the app. Look for one that shows exactly what it will remove, moves files to the Trash instead of deleting them, and cannot touch passwords or personal documents. iClearer labels every item Safe or Ask first, moves everything to the Trash with undo, and never selects Keychain, accounts, tokens or git repositories.",
      },
    ],
    related: ["how-to-clean-mac", "clear-system-data-mac", "find-large-files-mac"],
  },

  {
    slug: "how-to-clean-mac",
    featured: true,
    title: "How to Clean Up Your Mac: 10-Step Checklist",
    h1: "How to clean up your Mac: a 10-step checklist",
    card: "How to clean up your Mac",
    description:
      "A 10-step checklist to clean up a Mac and free up space: Trash, downloads, unused apps, caches, large files, old backups and more, safest steps first.",
    answer: `<p>To clean up a Mac, work from the safest step to the most involved: <b>empty the Trash, clear the Downloads folder, uninstall apps you do not use, clear app caches and logs, delete large files you no longer need, and remove old iPhone backups</b>. Check <b>System Settings → General → Storage</b> before and after to see how much space you got back. Everything on this list can be done for free with what is built into macOS.</p>`,
    toc: [
      ["checklist", "The 10-step checklist"],
      ["space", "Steps 1–7: get space back"],
      ["tidy", "Steps 8–10: keep it tidy"],
      ["faster", "Will cleaning make my Mac faster?"],
      ["do-not-delete", "What you should not delete"],
    ],
    body: `
<h2 id="checklist">The 10-step checklist</h2>
<div class="g-tbl"><table>
  <tr><th>Step</th><th>What to do</th><th>Typical space back</th></tr>
  <tr><td>1</td><td>Check what is using your storage</td><td>None, but it tells you where to look</td></tr>
  <tr><td>2</td><td>Empty the Trash</td><td>Varies</td></tr>
  <tr><td>3</td><td>Clear the Downloads folder</td><td>Often several GB</td></tr>
  <tr><td>4</td><td>Uninstall apps you do not use</td><td>Often several GB</td></tr>
  <tr><td>5</td><td>Clear app caches and logs</td><td>Often several GB</td></tr>
  <tr><td>6</td><td>Delete large and old files</td><td>Usually the most</td></tr>
  <tr><td>7</td><td>Remove old iPhone and iPad backups</td><td>Often tens of GB</td></tr>
  <tr><td>8</td><td>Trim Messages attachments</td><td>Varies</td></tr>
  <tr><td>9</td><td>Review what opens at login</td><td>None; helps startup time</td></tr>
  <tr><td>10</td><td>Restart and update macOS</td><td>A little</td></tr>
</table></div>

<h2 id="space">Steps 1–7: get space back</h2>
<h3>1. Check what is using your storage</h3>
<p>Open the Apple menu → <b>System Settings → General → Storage</b>. Wait for the bar to finish calculating and note the free space, so you can compare afterwards. Click the <b>i</b> next to a category to see what is in it.</p>

<h3>2. Empty the Trash</h3>
<p>Files in the Trash still use space. Right-click the Trash in the Dock and choose <b>Empty Trash</b>. To have macOS do this for you, turn on <b>Empty Trash Automatically</b> in Storage settings; it removes items that have been in the Trash for 30 days.</p>

<h3>3. Clear the Downloads folder</h3>
<p>Open Downloads in Finder, switch to List view and click the Size column. Installers (<code>.dmg</code>, <code>.pkg</code>) and <code>.zip</code> files you already opened are usually safe to delete.</p>

<h3>4. Uninstall apps you do not use</h3>
<p>Open Finder → Applications, switch to List view and sort by <b>Date Last Opened</b>. Drag apps you no longer use to the Trash. Their support files stay behind in your Library folder; <a href="/guides/uninstall-apps-mac">how to uninstall apps on Mac completely</a> shows where.</p>

<h3>5. Clear app caches and logs</h3>
<p>Quit your apps, then in Finder press <kbd>Shift</kbd> <kbd>Command</kbd> <kbd>G</kbd>, go to <code>~/Library/Caches</code> and move the contents of the largest folders to the Trash. Do the same in <code>~/Library/Logs</code>. Apps rebuild caches when they need them. Step-by-step: <a href="/guides/clear-cache-mac">how to clear cache on Mac</a>.</p>

<h3>6. Delete large and old files</h3>
<p>In Storage settings, click the <b>i</b> next to Documents and open <b>Large Files</b>. Old videos, disk images and virtual machines are the usual finds. More methods: <a href="/guides/find-large-files-mac">how to find large files on Mac</a>.</p>

<h3>7. Remove old iPhone and iPad backups</h3>
<p>In Storage settings, click the <b>i</b> next to <b>iOS Files</b>, select a backup you no longer need and click Delete. Keep the most recent backup of any device you still use. More detail: <a href="/guides/delete-iphone-backups-mac">how to delete old iPhone backups on Mac</a>.</p>

<h2 id="tidy">Steps 8–10: keep it tidy</h2>
<h3>8. Trim Messages attachments</h3>
<p>Photos and videos sent in Messages are stored on your Mac. In Storage settings, click the <b>i</b> next to <b>Messages</b> to see the largest attachments and delete the ones you do not need.</p>

<h3>9. Review what opens at login</h3>
<p>Open <b>System Settings → General → Login Items</b> (called Login Items &amp; Extensions on newer versions of macOS). Remove apps you do not need at startup. For background items, check which app each one belongs to before you switch it off. This does not free disk space, but your Mac starts faster.</p>

<h3>10. Restart and update macOS</h3>
<p>A restart clears temporary files and swap files. Then check <b>System Settings → General → Software Update</b>; after an update installs, macOS removes the installer it downloaded.</p>

<h2 id="faster">Will cleaning make my Mac faster?</h2>
<p>It depends on why it is slow. If the disk is nearly full, yes: macOS needs free space for swap files and updates, and a Mac with only a few gigabytes free can slow down noticeably. If you have plenty of free space, deleting caches will not speed anything up, because caches exist to make apps faster.</p>

<h2 id="do-not-delete">What you should not delete</h2>
<ul>
  <li>Anything in <code>/System</code> or <code>/usr</code>. That is macOS.</li>
  <li><code>~/Library/Keychains</code>, where your passwords are stored.</li>
  <li><code>~/Library/Application Support</code> folders for apps you still use. They hold your data, not cache.</li>
  <li>The only backup of a device you still use.</li>
</ul>
`,
    cta: {
      heading: "Do steps 3 to 7 in one scan",
      text: `<p>iClearer finds caches, logs, app leftovers, large and old files, unused apps and old iOS backups in one scan, with the size of each. Every item is labelled <b>Safe</b> or <b>Ask first</b>, you tick what goes, and it moves to the Trash so you can undo it.</p>`,
    },
    faq: [
      {
        q: "How do I clean my Mac for free?",
        a: "Use what is built into macOS. Open System Settings → General → Storage, empty the Trash, clear the Downloads folder, delete large files from the Documents list, and clear the folders in ~/Library/Caches. None of this needs extra software.",
      },
      {
        q: "Does a Mac have a built-in cleaner?",
        a: "Not a one-click cleaner. macOS has Storage settings (System Settings → General → Storage), which shows what is using space, lists large files and offers recommendations such as Empty Trash Automatically and Optimize Storage. It does not clear app caches or remove leftovers from deleted apps.",
      },
      {
        q: "How often should I clean up my Mac?",
        a: "When free space gets low, not on a schedule. A sensible trigger is when less than 10–15% of the disk is free, or when macOS warns that the disk is almost full.",
      },
      {
        q: "Will cleaning my Mac make it faster?",
        a: "Only if the disk was nearly full. macOS needs free space for swap files and updates, so freeing space on a full disk helps. On a Mac with plenty of free space, clearing caches does not improve speed.",
      },
      {
        q: "What is the safest thing to delete first on a Mac?",
        a: "The Trash, then old installers and zip files in Downloads, then app caches in ~/Library/Caches. These are either files you already chose to delete or files your apps can recreate.",
      },
    ],
    related: ["mac-storage-full", "clear-cache-mac", "uninstall-apps-mac"],
  },

  {
    slug: "clear-system-data-mac",
    featured: true,
    title: "How to Clear System Data on Mac (Safely)",
    h1: "How to clear System Data on Mac",
    card: "Clear System Data on Mac",
    description:
      "System Data taking up too much space? Learn what it contains and how to shrink it safely: caches, logs, Time Machine snapshots and app leftovers.",
    answer: `<p><b>System Data</b> is the catch-all category in Mac storage for files macOS does not sort anywhere else: caches, logs, temporary files, Time Machine local snapshots, swap files and files left behind by apps. You cannot delete the category directly. You shrink it by <b>restarting your Mac, clearing <code>~/Library/Caches</code> and <code>~/Library/Logs</code>, removing Time Machine local snapshots, and deleting leftovers from apps you uninstalled</b>.</p>`,
    toc: [
      ["what", "What System Data is"],
      ["restart", "Restart your Mac"],
      ["caches", "Clear caches and logs"],
      ["snapshots", "Remove Time Machine local snapshots"],
      ["leftovers", "Delete leftovers from apps you removed"],
      ["find", "Find what is still large"],
      ["do-not-delete", "What you should not delete"],
    ],
    body: `
<h2 id="what">What System Data is</h2>
<p>Open <b>System Settings → General → Storage</b> and you will see a grey section called System Data. On older versions of macOS it was called “Other”. It contains:</p>
<ul>
  <li>App caches, system caches and temporary files</li>
  <li>Log files</li>
  <li>Time Machine local snapshots</li>
  <li>Virtual memory (swap) files and the sleep image</li>
  <li>App support files, plug-ins and extensions, including files left by apps you deleted</li>
</ul>
<p>It is separate from the <b>macOS</b> category, which is the operating system itself and should be left alone.</p>

<h2 id="restart">1. Restart your Mac</h2>
<p>Start here because it costs nothing. A restart deletes temporary files and resets the swap files macOS builds up when memory runs low. If your Mac has been on for weeks, this alone can return several gigabytes.</p>

<h2 id="caches">2. Clear caches and logs</h2>
<ol>
  <li>Quit your open apps.</li>
  <li>In Finder, press <kbd>Shift</kbd> <kbd>Command</kbd> <kbd>G</kbd>, type <code>~/Library/Caches</code> and press Return.</li>
  <li>Press <kbd>Command</kbd> <kbd>J</kbd> and tick <b>Calculate All Sizes</b>.</li>
  <li>Move the contents of the largest folders to the Trash.</li>
  <li>Do the same in <code>~/Library/Logs</code>, then empty the Trash.</li>
</ol>
<p>Apps rebuild their caches the next time you open them. More detail in <a href="/guides/clear-cache-mac">how to clear cache on Mac</a>.</p>

<h2 id="snapshots">3. Remove Time Machine local snapshots</h2>
<p>If you use Time Machine, macOS keeps local snapshots on your startup disk so you can restore files when the backup drive is not connected. macOS deletes them automatically when it needs space, but you can remove them yourself. Open Terminal and list them:</p>
<pre><code>tmutil listlocalsnapshots /</code></pre>
<p>Delete one by its date stamp:</p>
<pre><code>sudo tmutil deletelocalsnapshots 2026-11-01-093000</code></pre>
<p>Or ask macOS to free about 20 GB of snapshot space:</p>
<pre><code>tmutil thinlocalsnapshots / 20000000000 4</code></pre>
<p class="g-note"><b>Note:</b> local snapshots are not your Time Machine backup. Deleting them does not touch the backups on your external drive.</p>
<p>More ways to remove them, including Disk Utility: <a href="/guides/delete-time-machine-local-snapshots">how to delete Time Machine local snapshots</a>.</p>

<h2 id="leftovers">4. Delete leftovers from apps you removed</h2>
<p>When you drag an app to the Trash, its support files stay behind. Check these folders for names of apps you no longer have:</p>
<ul>
  <li><code>~/Library/Application Support</code></li>
  <li><code>~/Library/Containers</code></li>
  <li><code>~/Library/Caches</code></li>
</ul>
<p>Only delete a folder if you are sure the app is gone. The full list of locations is in <a href="/guides/uninstall-apps-mac">how to uninstall apps on Mac completely</a>.</p>

<h2 id="find">5. Find what is still large</h2>
<p>This Terminal command lists the 15 largest folders in your Library, biggest last:</p>
<pre><code>du -sh ~/Library/* 2>/dev/null | sort -h | tail -15</code></pre>
<p>Common results are developer tools (Xcode, Docker, simulators), downloaded AI models and message attachments. If you write code, see <a href="/guides/free-up-disk-space-mac-developers">free up disk space on a Mac for developers</a>.</p>

<h2 id="do-not-delete">What you should not delete</h2>
<ul>
  <li>Anything in <code>/System</code>, <code>/usr</code> or <code>/private/var/vm</code>. macOS manages these.</li>
  <li><code>~/Library/Keychains</code>, which holds your passwords.</li>
  <li>Application Support folders for apps you still use. They hold your data, not cache.</li>
</ul>
`,
    cta: {
      heading: "Let iClearer find what is inside System Data",
      text: `<p>iClearer scans the caches, logs, temporary files and app leftovers that make up most of System Data, and shows the size of each one. Items macOS rebuilds are labelled <b>Safe</b>. Anything larger or system-related is labelled <b>Ask first</b> and starts unticked. Everything you clean goes to the Trash.</p>`,
    },
    faq: [
      {
        q: "Why is System Data so large on my Mac?",
        a: "The usual causes are app caches, Time Machine local snapshots, swap files from running low on memory, and files left behind by apps you deleted. Developer tools such as Xcode and Docker can also add tens of gigabytes.",
      },
      {
        q: "Can I delete System Data on a Mac?",
        a: "Not as a single item. System Data is a category, not a folder. You reduce it by clearing caches and logs, removing Time Machine local snapshots, deleting leftovers from uninstalled apps, and restarting your Mac.",
      },
      {
        q: "How much System Data is normal on a Mac?",
        a: "Apple does not publish a figure. A few tens of gigabytes is common. It is worth investigating when System Data is far larger than that or keeps growing week after week.",
      },
      {
        q: "Does restarting a Mac reduce System Data?",
        a: "Yes. A restart removes temporary files and resets the swap files macOS creates when memory runs low, which are both counted as System Data.",
      },
      {
        q: "Is System Data the same as macOS in the storage bar?",
        a: "No. The macOS category is the operating system and should not be touched. System Data is everything else macOS cannot sort into a category, such as caches, logs and snapshots.",
      },
    ],
    related: ["mac-storage-full", "delete-time-machine-local-snapshots", "clear-cache-mac"],
  },

  {
    slug: "clear-cache-mac",
    featured: true,
    title: "How to Clear Cache on Mac: Apps, Browsers, System",
    h1: "How to clear cache on Mac",
    card: "Clear cache on Mac",
    description:
      "Clear app, browser and system caches on a Mac safely. Step-by-step for Finder, Safari, Chrome and Firefox, plus what is safe to delete and what is not.",
    answer: `<p>To clear app caches on a Mac, quit your apps, open Finder, press <kbd>Shift</kbd> <kbd>Command</kbd> <kbd>G</kbd>, go to <code>~/Library/Caches</code>, move the contents of the folders you want to clear to the Trash, and empty the Trash. Browser caches are cleared from inside each browser. <b>Deleting caches is safe</b>: apps rebuild them, though the first launch afterwards can be a little slower.</p>`,
    toc: [
      ["types", "The kinds of cache on a Mac"],
      ["app-cache", "Clear app caches"],
      ["browser-cache", "Clear browser caches"],
      ["system-cache", "Clear system caches"],
      ["safe", "Is it safe, and how often?"],
    ],
    body: `
<h2 id="types">The kinds of cache on a Mac</h2>
<div class="g-tbl"><table>
  <tr><th>Cache</th><th>Where it lives</th><th>Safe to clear?</th></tr>
  <tr><td>App (user) cache</td><td><code>~/Library/Caches</code></td><td>Yes. Apps rebuild it.</td></tr>
  <tr><td>Browser cache</td><td>Each browser’s own folder, mostly under <code>~/Library/Caches</code></td><td>Yes. Pages reload once.</td></tr>
  <tr><td>System cache</td><td><code>/Library/Caches</code></td><td>Usually. macOS rebuilds it.</td></tr>
  <tr><td>Developer caches</td><td><code>~/.npm</code>, <code>~/Library/Caches/Homebrew</code>, Xcode DerivedData</td><td>Yes. Tools download or rebuild.</td></tr>
</table></div>

<h2 id="app-cache">Clear app caches</h2>
<ol>
  <li>Quit the apps whose cache you want to clear.</li>
  <li>In Finder, press <kbd>Shift</kbd> <kbd>Command</kbd> <kbd>G</kbd>.</li>
  <li>Type <code>~/Library/Caches</code> and press Return.</li>
  <li>Press <kbd>Command</kbd> <kbd>J</kbd> and tick <b>Calculate All Sizes</b> to see which folders are big.</li>
  <li>Open a large folder and move its contents to the Trash. Keeping the folder itself avoids permission problems.</li>
  <li>Empty the Trash to get the space back.</li>
</ol>

<h2 id="browser-cache">Clear browser caches</h2>
<h3>Safari</h3>
<ol>
  <li>Open Safari → Settings → Advanced and tick <b>Show features for web developers</b>. On older versions it is called Show Develop menu in menu bar.</li>
  <li>Choose <b>Develop → Empty Caches</b>, or press <kbd>Option</kbd> <kbd>Command</kbd> <kbd>E</kbd>.</li>
</ol>
<h3>Chrome</h3>
<ol>
  <li>Press <kbd>Shift</kbd> <kbd>Command</kbd> <kbd>Delete</kbd>.</li>
  <li>Tick <b>Cached images and files</b>, choose a time range and confirm.</li>
</ol>
<h3>Firefox</h3>
<ol>
  <li>Open Firefox → Settings → Privacy &amp; Security.</li>
  <li>Under Cookies and Site Data, click <b>Clear Data</b>, tick the cached files option and confirm.</li>
</ol>
<p class="g-note"><b>Note:</b> clearing the cache does not sign you out. Clearing <i>cookies</i> does, so leave that box unticked if you want to stay logged in.</p>

<h2 id="system-cache">Clear system caches</h2>
<p>System caches live in <code>/Library/Caches</code> (no <code>~</code> at the start). macOS and shared components rebuild them, and they are usually small. You will be asked for your password to remove them. Leave <code>/System/Library/Caches</code> alone, because macOS protects and manages it.</p>

<h2 id="safe">Is it safe, and how often should you do it?</h2>
<p>Clearing caches is safe. The trade-off is speed: caches exist so apps do not have to download or rebuild the same data, so the first launch after clearing can be slower and the cache will grow back.</p>
<p>That is why you do not need to clear caches on a schedule. Do it when you are short on space, or when one app is misbehaving and a fresh cache might fix it.</p>
`,
    cta: {
      heading: "Clear every cache in one pass with iClearer",
      text: `<p>iClearer finds app caches, browser caches, system caches, logs and developer caches in one scan and shows how much space each one uses. Caches your Mac rebuilds are labelled <b>Safe</b>. You tick what goes, and it moves to the Trash so you can undo it.</p>`,
    },
    faq: [
      {
        q: "Is it safe to delete everything in ~/Library/Caches?",
        a: "Yes. Everything in ~/Library/Caches is data apps can recreate. Quit your apps first, and delete the contents of the folders rather than the folders themselves. Apps may open more slowly the first time afterwards.",
      },
      {
        q: "Will clearing the cache delete my passwords or log me out?",
        a: "No. Caches hold temporary copies of data, not passwords. Passwords are stored in Keychain. You are only signed out of websites if you also clear cookies.",
      },
      {
        q: "Does clearing the cache make a Mac faster?",
        a: "Not usually. It frees disk space and can fix an app that is behaving oddly, but caches exist to make apps faster, so apps can feel slower until the cache rebuilds. A Mac with a nearly full disk does run better once space is freed.",
      },
      {
        q: "How often should I clear the cache on my Mac?",
        a: "Only when you need the space or an app is misbehaving. There is no benefit to clearing caches on a fixed schedule, because they grow back as you use your apps.",
      },
      {
        q: "Where are cache files stored on a Mac?",
        a: "App caches are in ~/Library/Caches, system caches are in /Library/Caches, and browsers keep theirs in their own folders, mostly under ~/Library/Caches. In Finder, press Shift-Command-G and type the path to open any of them.",
      },
    ],
    related: ["mac-storage-full", "clear-system-data-mac", "free-up-disk-space-mac-developers"],
  },

  {
    slug: "free-up-disk-space-mac-developers",
    featured: true,
    group: "dev",
    title: "Free Up Disk Space on Mac for Developers",
    h1: "Free up disk space on a Mac for developers",
    card: "Free up space for developers",
    description:
      "Reclaim tens of gigabytes on a developer Mac. Safe commands to clear Xcode DerivedData, npm, pnpm, pip, Homebrew, Docker, simulators and AI model caches.",
    answer: `<p>On a developer’s Mac, most reclaimable space is in build caches and package downloads, and nearly all of it is safe to delete because the tools rebuild it. The biggest wins are usually <b>Xcode DerivedData and simulators</b>, <b>Docker images and build cache</b>, <b>npm, pnpm and Yarn caches</b>, <b>Homebrew downloads</b>, and <b>downloaded AI models</b>.</p>
<pre><code>rm -rf ~/Library/Developer/Xcode/DerivedData
xcrun simctl delete unavailable
npm cache clean --force
brew cleanup --prune=all
pip cache purge
docker system prune</code></pre>`,
    toc: [
      ["xcode", "Xcode"],
      ["node", "Node: npm, pnpm, Yarn and node_modules"],
      ["python", "Python and AI tooling"],
      ["homebrew", "Homebrew"],
      ["docker", "Docker"],
      ["mobile", "CocoaPods and Gradle"],
      ["editors", "Cursor and VS Code"],
      ["never", "What to never delete"],
    ],
    body: `
<h2 id="xcode">Xcode</h2>
<div class="g-tbl"><table>
  <tr><th>What</th><th>Path</th><th>Safe?</th></tr>
  <tr><td>DerivedData (build cache)</td><td><code>~/Library/Developer/Xcode/DerivedData</code></td><td>Yes. Rebuilt on the next build.</td></tr>
  <tr><td>iOS DeviceSupport</td><td><code>~/Library/Developer/Xcode/iOS DeviceSupport</code></td><td>Yes. Recreated when you connect a device.</td></tr>
  <tr><td>Simulator data</td><td><code>~/Library/Developer/CoreSimulator</code></td><td>Ask first. You lose simulator app data.</td></tr>
  <tr><td>Archives</td><td><code>~/Library/Developer/Xcode/Archives</code></td><td>Keep archives of builds you shipped; they hold the symbols for crash reports.</td></tr>
</table></div>
<pre><code>rm -rf ~/Library/Developer/Xcode/DerivedData
xcrun simctl delete unavailable</code></pre>
<p>The second command removes simulators for runtimes you no longer have installed. To remove whole simulator runtimes, open Xcode → Settings → Components (called Platforms in Xcode 15). More detail: <a href="/guides/delete-xcode-derived-data">how to delete Xcode DerivedData</a>.</p>

<h2 id="node">Node: npm, pnpm, Yarn and node_modules</h2>
<pre><code>npm cache clean --force
pnpm store prune
yarn cache clean</code></pre>
<p>Old <code>node_modules</code> folders in projects you no longer work on add up quickly. This lists the 20 largest:</p>
<pre><code>find ~ -name node_modules -type d -prune -exec du -sh {} + 2>/dev/null | sort -h | tail -20</code></pre>
<p>Deleting a <code>node_modules</code> folder is safe. Run your package manager’s install command to bring it back. More detail: <a href="/guides/clear-npm-cache-node-modules-mac">how to clear npm cache and node_modules</a>.</p>

<h2 id="python">Python and AI tooling</h2>
<pre><code>pip cache purge
uv cache clean</code></pre>
<p>Many tools also write to <code>~/.cache</code>, including Hugging Face downloads. Downloaded models are often the largest thing on the disk. For Ollama:</p>
<pre><code>ollama list
ollama rm &lt;model-name&gt;</code></pre>
<p class="g-note"><b>Note:</b> models are safe to remove but slow to get back. You will have to download them again.</p>
<p>Where each tool keeps its models: <a href="/guides/delete-ollama-models-mac">delete Ollama models on Mac</a>.</p>

<h2 id="homebrew">Homebrew</h2>
<pre><code>brew cleanup --prune=all
brew autoremove</code></pre>
<p>The first removes old versions and every cached download. The second removes dependencies nothing needs any more.</p>

<h2 id="docker">Docker</h2>
<p>See what Docker is using first:</p>
<pre><code>docker system df</code></pre>
<p>Then remove stopped containers, unused networks, dangling images and build cache:</p>
<pre><code>docker system prune</code></pre>
<p class="g-note"><b>Careful:</b> <code>docker system prune -a --volumes</code> also removes every image not used by a running container and all unused volumes. Volumes can hold database data that cannot be rebuilt.</p>
<p>Docker Desktop keeps everything inside one disk image, so Finder shows a single large file. Use the Docker commands rather than deleting that file by hand. More detail: <a href="/guides/docker-disk-space-mac">Docker taking up too much space on Mac</a>.</p>

<h2 id="mobile">CocoaPods and Gradle</h2>
<pre><code>pod cache clean --all
rm -rf ~/.gradle/caches</code></pre>
<p>Both download what they need on the next build.</p>

<h2 id="editors">Cursor and VS Code</h2>
<p>The caches are safe to clear: <code>~/Library/Application Support/Cursor/Cache</code>, <code>~/Library/Application Support/Cursor/CachedData</code> and <code>~/Library/Application Support/Code/Cache</code>.</p>
<p>Do not delete the <code>User</code> folder next to them. It holds your settings, keybindings, extensions state and chat history.</p>

<h2 id="never">What to never delete</h2>
<ul>
  <li><code>~/.ssh</code> — your SSH keys</li>
  <li><code>.env</code> files and API tokens</li>
  <li><code>.git</code> folders — your commit history</li>
  <li><code>~/Library/Keychains</code> — signing certificates and passwords</li>
  <li>Editor <code>User</code> folders — settings and chats</li>
  <li>Docker volumes that hold data you need</li>
</ul>
`,
    cta: {
      heading: "iClearer has a Builders pack for this",
      text: `<p>iClearer’s Builders screen finds npm, pnpm, Yarn, pip and Homebrew caches, Xcode DerivedData, CocoaPods and Gradle caches, Cursor and VS Code caches, iOS Simulator data, Docker data and Ollama models, with the size of each. Rebuildable caches are labelled <b>Safe</b>; simulators, Docker and models are <b>Ask first</b>. API tokens, SSH keys, <code>.env</code> files and git repositories can never be selected.</p>`,
    },
    faq: [
      {
        q: "Is it safe to delete Xcode DerivedData?",
        a: "Yes. DerivedData is Xcode’s build cache and index. Deleting it is safe; Xcode rebuilds it the next time you build, so that build will take longer than usual.",
      },
      {
        q: "Is it safe to delete the npm cache?",
        a: "Yes. The npm cache in ~/.npm holds downloaded packages. Run npm cache clean --force to clear it. npm downloads packages again when you next install them.",
      },
      {
        q: "What does docker system prune remove?",
        a: "It removes stopped containers, unused networks, dangling images and build cache. It does not remove volumes or images that are still tagged unless you add -a and --volumes, which can delete data you want to keep.",
      },
      {
        q: "Why is my Mac storage full after installing Xcode?",
        a: "Xcode itself is large, and it adds simulator runtimes, device support files and a DerivedData build cache that grows with every project. Deleting DerivedData and unused simulators usually returns the most space.",
      },
      {
        q: "How do I find which developer folders are using the most space?",
        a: "Run du -sh ~/Library/Developer ~/.npm ~/.cache ~/.gradle ~/.docker 2>/dev/null in Terminal to see the size of the common ones, or use a disk cleaner such as iClearer that lists developer caches by size.",
      },
    ],
    related: ["delete-xcode-derived-data", "docker-disk-space-mac", "clear-npm-cache-node-modules-mac"],
  },

  {
    slug: "uninstall-apps-mac",
    title: "How to Uninstall Apps on Mac Completely",
    h1: "How to uninstall apps on Mac completely",
    card: "Uninstall apps and leftovers",
    description:
      "Dragging an app to the Trash leaves files behind. See where Mac app leftovers live and how to remove an app completely, with its caches and settings.",
    answer: `<p>To uninstall an app on a Mac, open <b>Finder → Applications</b>, drag the app to the Trash and empty the Trash. That removes the app itself but <b>leaves its support files behind</b> in your Library folder. To remove an app completely, also delete its folders in <code>~/Library/Application Support</code>, <code>~/Library/Caches</code>, <code>~/Library/Containers</code> and its file in <code>~/Library/Preferences</code>.</p>`,
    toc: [
      ["basic", "Remove the app"],
      ["leftovers", "Where leftovers live"],
      ["find", "Find an app’s leftover files"],
      ["special", "Apps with their own uninstaller"],
    ],
    body: `
<h2 id="basic">1. Remove the app</h2>
<ol>
  <li>Quit the app. If it will not quit, press <kbd>Option</kbd> <kbd>Command</kbd> <kbd>Esc</kbd> and force quit it.</li>
  <li>Open <b>Finder → Applications</b>.</li>
  <li>Drag the app to the Trash, or select it and press <kbd>Command</kbd> <kbd>Delete</kbd>.</li>
  <li>Empty the Trash.</li>
</ol>

<h2 id="leftovers">2. Where leftovers live</h2>
<p>Apps store their data outside the app itself, and macOS does not remove it when the app goes. These are the usual places:</p>
<div class="g-tbl"><table>
  <tr><th>Folder</th><th>What is in it</th></tr>
  <tr><td><code>~/Library/Application Support</code></td><td>App data, often the largest leftover</td></tr>
  <tr><td><code>~/Library/Caches</code></td><td>Cached files</td></tr>
  <tr><td><code>~/Library/Containers</code> and <code>~/Library/Group Containers</code></td><td>Data for sandboxed and App Store apps</td></tr>
  <tr><td><code>~/Library/Preferences</code></td><td>Settings files ending in <code>.plist</code></td></tr>
  <tr><td><code>~/Library/Logs</code></td><td>Log files</td></tr>
  <tr><td><code>~/Library/Saved Application State</code></td><td>Window positions from the last session</td></tr>
  <tr><td><code>~/Library/LaunchAgents</code></td><td>Helpers that start when you log in</td></tr>
</table></div>

<h2 id="find">3. Find an app’s leftover files</h2>
<p>Leftovers are named after the app or after its bundle identifier, which looks like <code>com.company.appname</code>. Before you delete the app, get its identifier in Terminal (replace Slack with the app’s name):</p>
<pre><code>osascript -e 'id of app "Slack"'</code></pre>
<p>Then, in Finder, press <kbd>Shift</kbd> <kbd>Command</kbd> <kbd>G</kbd>, open each folder in the table above, and look for the app’s name or identifier. Move what you find to the Trash.</p>
<p class="g-note"><b>Check the name twice.</b> Several apps from the same company can share a folder, so make sure a folder belongs only to the app you removed.</p>

<h2 id="special">Apps with their own uninstaller</h2>
<p>Some apps install drivers, system extensions or background services. These usually ship an uninstaller, either inside the app’s folder in Applications or as a download from the developer. Use it, because it removes parts that dragging to the Trash cannot.</p>
<p>Apps that came with macOS, such as Safari and Mail, are protected by the system and cannot be removed.</p>
`,
    cta: {
      heading: "Uninstall an app and its leftovers in one click",
      text: `<p>iClearer’s Apps screen lists your apps with the size of the app and the size of its leftovers, and shows which ones you have not opened in months. Uninstalling removes the app and everything it left behind, and it all goes to the Trash so you can restore it. The app list is free; uninstalling is part of the paid plan.</p>`,
    },
    faq: [
      {
        q: "Does dragging an app to the Trash uninstall it completely?",
        a: "No. It removes the app itself, but support files, caches, preferences and containers stay in your Library folder. They can take up more space than the app did.",
      },
      {
        q: "Where are leftover app files stored on a Mac?",
        a: "Mostly in ~/Library/Application Support, ~/Library/Caches, ~/Library/Containers, ~/Library/Preferences and ~/Library/Logs. They are named after the app or its bundle identifier, such as com.company.appname.",
      },
      {
        q: "How do I uninstall an app that will not delete?",
        a: "The app is probably still running. Quit it, or press Option-Command-Esc to force quit it, then try again. If macOS asks for a password, you need an administrator account to remove it.",
      },
      {
        q: "Can I delete the apps that came with my Mac?",
        a: "Not the ones that are part of macOS, such as Safari, Mail and Messages. They are protected by the system and take no extra space you can reclaim.",
      },
      {
        q: "Is it safe to delete leftover files from uninstalled apps?",
        a: "Yes, as long as the folder belongs only to the app you removed. Deleting leftovers also deletes that app’s settings and saved data, so keep them if you plan to reinstall the app and want your settings back.",
      },
    ],
    related: ["mac-storage-full", "clear-system-data-mac", "find-large-files-mac"],
  },

  {
    slug: "find-large-files-mac",
    featured: true,
    title: "How to Find Large Files on Mac (3 Ways)",
    h1: "How to find large files on Mac",
    card: "Find large files on Mac",
    description:
      "Three ways to find the biggest files on your Mac: Storage settings, Finder search by file size, and a Terminal command. See what is safe to delete.",
    answer: `<p>The quickest way to find large files on a Mac is <b>System Settings → General → Storage</b>: click the <b>i</b> next to Documents and open the <b>Large Files</b> tab. You can also search by size in Finder (press <kbd>Command</kbd> <kbd>F</kbd> and add a <b>File Size</b> filter) or list every file over 1 GB in Terminal with <code>find ~ -type f -size +1G</code>.</p>`,
    toc: [
      ["settings", "Storage settings"],
      ["finder", "Finder search by file size"],
      ["terminal", "Terminal"],
      ["usual", "What is usually big"],
      ["before", "Before you delete"],
    ],
    body: `
<h2 id="settings">1. Storage settings</h2>
<ol>
  <li>Open the Apple menu → <b>System Settings → General → Storage</b>.</li>
  <li>Click the <b>i</b> next to <b>Documents</b>.</li>
  <li>Open the <b>Large Files</b> tab. Files are sorted biggest first, with the date you last opened them.</li>
  <li>Select a file and click Delete, or Show in Finder to look at it first.</li>
</ol>
<p>The <b>Downloads</b> tab in the same window is worth a look too.</p>

<h2 id="finder">2. Finder search by file size</h2>
<ol>
  <li>Open a Finder window and press <kbd>Command</kbd> <kbd>F</kbd>.</li>
  <li>Make sure the search covers <b>This Mac</b>.</li>
  <li>Click the first filter menu (it says Kind) and choose <b>Other…</b></li>
  <li>Find <b>File Size</b> in the list, tick it and click OK.</li>
  <li>Set the filter to <b>is greater than</b> 1 <b>GB</b>.</li>
</ol>
<p>Lower the number to 500 MB to see more. By default Finder’s search leaves out hidden and system folders, so it will not show files inside the Library.</p>

<h2 id="terminal">3. Terminal</h2>
<p>This lists every file over 1 GB in your home folder, with its size, including hidden ones:</p>
<pre><code>find ~ -type f -size +1G -exec ls -lh {} + 2>/dev/null</code></pre>
<p>To see which <i>folders</i> are largest instead:</p>
<pre><code>du -sh ~/* 2>/dev/null | sort -h | tail -15</code></pre>

<h2 id="usual">What is usually big</h2>
<ul>
  <li><b>Videos and screen recordings</b> in Movies, Desktop and Downloads</li>
  <li><b>Virtual machines</b> from Parallels, VMware or UTM</li>
  <li><b>Disk images and installers</b> (<code>.dmg</code>, <code>.iso</code>, <code>.pkg</code>)</li>
  <li><b>Old iPhone and iPad backups</b> in <code>~/Library/Application Support/MobileSync/Backup</code> (see <a href="/guides/delete-iphone-backups-mac">how to delete old iPhone backups</a>)</li>
  <li><b>Archives</b> you already unzipped</li>
  <li><b>Downloaded AI models</b> and other developer files, covered in <a href="/guides/free-up-disk-space-mac-developers">the developer guide</a></li>
</ul>

<h2 id="before">Before you delete</h2>
<ul>
  <li>Select a file and press <kbd>Space</kbd> to preview it with Quick Look.</li>
  <li>Move files to the Trash rather than deleting them outright, and empty the Trash once you are sure.</li>
  <li>For anything you cannot replace, check that your Time Machine or iCloud backup is recent first.</li>
</ul>
`,
    cta: {
      heading: "See every large file and where your space went",
      text: `<p>iClearer’s Large &amp; Old Files screen lists the biggest files you have not opened in months, and its Storage Map breaks your whole disk down by category. Preview a file with Quick Look before it moves, and everything you remove goes to the Trash. The free plan shows the kind and size of your top five; names, locations and Quick Look are part of the paid plan.</p>`,
    },
    faq: [
      {
        q: "How do I see what is taking up space on my Mac?",
        a: "Open System Settings → General → Storage. The bar shows space by category, and the i button next to each category lists what is inside. For a folder-by-folder view, run du -sh ~/* in Terminal or use a storage map tool.",
      },
      {
        q: "How do I find files larger than 1 GB on a Mac?",
        a: "In Finder, press Command-F, add a File Size filter and set it to is greater than 1 GB. In Terminal, run find ~ -type f -size +1G to list them, including files in hidden folders.",
      },
      {
        q: "Why can I not find the large files using my storage?",
        a: "They are probably in hidden folders. By default Finder’s search leaves out the Library folder, where caches, app data, device backups and developer files live. Use the Terminal command or a tool that scans the Library.",
      },
      {
        q: "Is it safe to delete large files in the Library folder?",
        a: "Sometimes. Caches and old device backups are safe to remove, but Application Support folders hold data for apps you use. Check what a file belongs to before you delete it, and move it to the Trash first so you can put it back.",
      },
      {
        q: "What file types usually take the most space on a Mac?",
        a: "Videos, virtual machines, disk images, old iPhone backups and photo libraries. On developer Macs, simulator data, Docker images and downloaded AI models are often larger still.",
      },
    ],
    related: ["mac-storage-full", "delete-iphone-backups-mac", "uninstall-apps-mac"],
  },

  {
    slug: "delete-iphone-backups-mac",
    title: "How to Delete Old iPhone Backups on Mac",
    h1: "How to delete old iPhone backups on Mac",
    card: "Delete old iPhone backups",
    description:
      "Old iPhone and iPad backups can take tens of gigabytes on a Mac. See where they are stored and three ways to delete them safely, with or without the device.",
    answer: `<p>To delete old iPhone backups on a Mac, open <b>System Settings → General → Storage</b>, click the <b>i</b> next to <b>iOS Files</b>, select the backup and click <b>Delete</b>. With the iPhone connected, you can also open it in Finder and choose <b>Manage Backups</b>. Backups are stored in <code>~/Library/Application Support/MobileSync/Backup</code>. Deleting a backup removes nothing from the iPhone itself.</p>`,
    toc: [
      ["storage", "Delete from Storage settings"],
      ["finder", "Delete from Finder with the device connected"],
      ["folder", "Delete from the backup folder"],
      ["keep", "Which backups to keep"],
    ],
    body: `
<h2 id="storage">1. Delete from Storage settings</h2>
<p>This works without the device and shows the size of each backup.</p>
<ol>
  <li>Open the Apple menu → <b>System Settings → General → Storage</b>.</li>
  <li>Click the <b>i</b> next to <b>iOS Files</b>. If you do not see iOS Files, there are no device backups on this Mac.</li>
  <li>Select a backup. The list shows the device name, the date and the size.</li>
  <li>Click <b>Delete</b> and confirm.</li>
</ol>

<h2 id="finder">2. Delete from Finder with the device connected</h2>
<ol>
  <li>Connect the iPhone or iPad to your Mac with a cable.</li>
  <li>Open Finder and select the device in the sidebar.</li>
  <li>In the <b>General</b> tab, click <b>Manage Backups</b>.</li>
  <li>Select a backup, click <b>Delete Backup</b> and confirm.</li>
</ol>
<p>On macOS Mojave or earlier, backups are managed in iTunes instead: iTunes → Preferences → Devices.</p>

<h2 id="folder">3. Delete from the backup folder</h2>
<ol>
  <li>In Finder, press <kbd>Shift</kbd> <kbd>Command</kbd> <kbd>G</kbd>.</li>
  <li>Enter <code>~/Library/Application Support/MobileSync/Backup</code> and press Return.</li>
  <li>Each folder with a long name of letters and numbers is one backup. Press <kbd>Command</kbd> <kbd>J</kbd> and tick <b>Calculate All Sizes</b> to see how big each one is.</li>
  <li>Move the ones you do not need to the Trash, then empty the Trash.</li>
</ol>
<p class="g-note"><b>Note:</b> folder names do not tell you which device a backup belongs to. Use the Storage settings or Finder method if you have backups of more than one device.</p>

<h2 id="keep">Which backups to keep</h2>
<ul>
  <li><b>Keep</b> the most recent backup of every device you still use, unless that device also backs up to iCloud.</li>
  <li><b>Safe to delete:</b> backups of devices you sold or replaced, and older backups of a device that has a newer one.</li>
  <li>A backup cannot be rebuilt once it is gone. If you are not sure, copy the folder to an external drive first.</li>
</ul>
<p>iCloud backups are separate. They are stored by Apple, not on your Mac, and deleting a backup on your Mac does not affect them.</p>
`,
    cta: {
      heading: "iClearer shows old backups with everything else",
      text: `<p>iClearer lists old iOS backups alongside caches, logs, leftovers and large files, with the size of each. Because a backup cannot be rebuilt, it is labelled <b>Ask first</b> and starts unticked. Anything you remove goes to the Trash, so you can put it back.</p>`,
    },
    faq: [
      {
        q: "Is it safe to delete old iPhone backups on a Mac?",
        a: "Yes, as long as you keep the most recent backup of any device you still use, or that device backs up to iCloud. Deleting a backup removes only the copy on your Mac. Nothing on the iPhone changes.",
      },
      {
        q: "Where are iPhone backups stored on a Mac?",
        a: "In ~/Library/Application Support/MobileSync/Backup. Each backup is a folder with a long name made of letters and numbers. In Finder, press Shift-Command-G and enter that path to open it.",
      },
      {
        q: "How much space do iPhone backups take on a Mac?",
        a: "Roughly as much as the data on the device, so often tens of gigabytes each. System Settings → General → Storage → iOS Files shows the exact size of every backup.",
      },
      {
        q: "Does deleting a backup on my Mac delete my iCloud backup?",
        a: "No. iCloud backups are stored by Apple and are managed separately on the device, under Settings → your name → iCloud. Backups on your Mac and backups in iCloud do not affect each other.",
      },
      {
        q: "Why can I not see iOS Files in Storage settings?",
        a: "iOS Files only appears when the Mac has at least one device backup or downloaded iOS software update. If it is missing, there are no backups stored on this Mac.",
      },
    ],
    related: ["mac-storage-full", "find-large-files-mac", "clear-system-data-mac"],
  },

  {
    slug: "delete-time-machine-local-snapshots",
    title: "Delete Time Machine Local Snapshots on Mac",
    h1: "How to delete Time Machine local snapshots on Mac",
    card: "Delete Time Machine local snapshots",
    description:
      "Time Machine local snapshots can hold many gigabytes on your startup disk. See how to list, delete and thin them in Terminal or Disk Utility, safely.",
    answer: `<p>Time Machine local snapshots are copies of recent changes that macOS keeps on your startup disk for about 24 hours. macOS deletes them automatically when it needs space, but you can remove them yourself. List them with <code>tmutil listlocalsnapshots /</code>, then delete one with <code>sudo tmutil deletelocalsnapshots</code> followed by its date. Deleting local snapshots <b>does not delete your Time Machine backups</b> on the backup drive.</p>`,
    toc: [
      ["what", "What local snapshots are"],
      ["list", "List your snapshots"],
      ["delete", "Delete snapshots in Terminal"],
      ["disk-utility", "Delete snapshots in Disk Utility"],
      ["stop", "Stop new snapshots"],
    ],
    body: `
<h2 id="what">What local snapshots are</h2>
<p>When Time Machine is set to back up automatically, macOS saves a snapshot of your startup disk about once an hour and keeps each one for up to 24 hours. They let you restore a file even when the backup drive is not plugged in.</p>
<p>The space they use is counted as available by Finder, because macOS will delete snapshots when something else needs the room. That is why Finder and Storage settings can show different amounts of free space. Sometimes an app or installer still reports that there is not enough space, and removing snapshots by hand fixes that.</p>

<h2 id="list">1. List your snapshots</h2>
<p>Open Terminal (Applications → Utilities) and run:</p>
<pre><code>tmutil listlocalsnapshots /</code></pre>
<p>Each line ends with a date stamp such as <code>2026-11-01-093000</code>. If nothing is listed, there are no local snapshots.</p>

<h2 id="delete">2. Delete snapshots in Terminal</h2>
<p>Delete one snapshot by its date stamp:</p>
<pre><code>sudo tmutil deletelocalsnapshots 2026-11-01-093000</code></pre>
<p>Delete all of them:</p>
<pre><code>for d in $(tmutil listlocalsnapshotdates / | grep -v :); do sudo tmutil deletelocalsnapshots $d; done</code></pre>
<p>Or ask macOS to free a set amount. This asks for about 20 GB at the highest urgency:</p>
<pre><code>tmutil thinlocalsnapshots / 20000000000 4</code></pre>
<p>You will be asked for your Mac password for the <code>sudo</code> commands. Nothing appears as you type it.</p>

<h2 id="disk-utility">3. Delete snapshots in Disk Utility</h2>
<ol>
  <li>Open Disk Utility (Applications → Utilities).</li>
  <li>Choose <b>View → Show APFS Snapshots</b>.</li>
  <li>Select your data volume in the sidebar, usually <b>Macintosh HD - Data</b> or <b>Data</b>.</li>
  <li>Select a snapshot in the list at the bottom and click the <b>minus</b> button.</li>
</ol>
<p class="g-note"><b>Note:</b> a snapshot named <code>com.apple.os.update</code> belongs to macOS itself. Leave it alone.</p>

<h2 id="stop">Stop new snapshots</h2>
<p>Local snapshots are only made while automatic backups are on. To stop them, open <b>System Settings → General → Time Machine → Options</b> and set the backup frequency to <b>Manually</b>. Your Mac will then only back up when you choose Back Up Now, so do this only if you will remember to.</p>
`,
    cta: {
      heading: "Then clear the rest of System Data",
      text: `<p>iClearer does not remove snapshots; macOS manages those. It finds the other things that fill System Data: app caches, system caches, logs, temporary files and leftovers from apps you removed. Each is listed with its size and a <b>Safe</b> or <b>Ask first</b> label, and what you clean goes to the Trash.</p>`,
    },
    faq: [
      {
        q: "Is it safe to delete Time Machine local snapshots?",
        a: "Yes. Local snapshots are short-term copies kept on your startup disk. Deleting them does not delete the backups on your Time Machine drive. You only lose the ability to restore files from the last 24 hours while the backup drive is disconnected.",
      },
      {
        q: "Do local snapshots take up space on a Mac?",
        a: "Yes, but macOS treats that space as available and deletes snapshots automatically when it is needed. Finder counts it as free, while some apps and Storage settings may not.",
      },
      {
        q: "How long does a Mac keep local snapshots?",
        a: "Up to 24 hours each. macOS makes roughly one per hour while automatic Time Machine backups are on, and removes older ones or removes them sooner when disk space runs low.",
      },
      {
        q: "How do I delete all local snapshots at once?",
        a: "Run this in Terminal: for d in $(tmutil listlocalsnapshotdates / | grep -v :); do sudo tmutil deletelocalsnapshots $d; done. It lists every snapshot date and deletes each one.",
      },
      {
        q: "Why do local snapshots come back after I delete them?",
        a: "macOS creates a new one about every hour while automatic Time Machine backups are on. To stop them, set Time Machine to back up manually in System Settings → General → Time Machine → Options.",
      },
    ],
    related: ["clear-system-data-mac", "mac-storage-full", "clear-cache-mac"],
  },

  {
    slug: "delete-xcode-derived-data",
    group: "dev",
    title: "How to Delete Xcode DerivedData (Is It Safe?)",
    h1: "How to delete Xcode DerivedData",
    card: "Delete Xcode DerivedData",
    description:
      "Xcode DerivedData can grow to tens of gigabytes. It is safe to delete. See where it is, three ways to clear it, and what else Xcode leaves on your disk.",
    answer: `<p><b>Yes, it is safe to delete Xcode DerivedData.</b> It holds build products, indexes and logs that Xcode recreates the next time you build. Quit Xcode, then run:</p>
<pre><code>rm -rf ~/Library/Developer/Xcode/DerivedData</code></pre>
<p>The first build of each project afterwards takes longer, and Swift packages are resolved again. Your source code and project settings are not stored there.</p>`,
    toc: [
      ["what", "What DerivedData is"],
      ["size", "Check how big it is"],
      ["delete", "Three ways to delete it"],
      ["more", "What else Xcode leaves behind"],
    ],
    body: `
<h2 id="what">What DerivedData is</h2>
<p>DerivedData is where Xcode keeps everything it generates from your projects: compiled build products, the code index, module caches, build logs and checked-out Swift packages. It lives at:</p>
<pre><code>~/Library/Developer/Xcode/DerivedData</code></pre>
<p>There is one folder per project, named after the project followed by a random string. Folders for projects you deleted or have not opened in a year are still there.</p>

<h2 id="size">Check how big it is</h2>
<pre><code>du -sh ~/Library/Developer/Xcode/DerivedData</code></pre>
<p>To see it per project, largest last:</p>
<pre><code>du -sh ~/Library/Developer/Xcode/DerivedData/* | sort -h</code></pre>

<h2 id="delete">Three ways to delete it</h2>
<h3>1. Terminal</h3>
<p>Quit Xcode first, then:</p>
<pre><code>rm -rf ~/Library/Developer/Xcode/DerivedData</code></pre>
<p>Xcode creates the folder again when it next opens.</p>

<h3>2. From Xcode settings</h3>
<ol>
  <li>Open <b>Xcode → Settings → Locations</b>.</li>
  <li>Click the small arrow next to the Derived Data path. Finder opens with the folder selected.</li>
  <li>Quit Xcode, then move the DerivedData folder, or the project folders inside it, to the Trash.</li>
</ol>

<h3>3. One project only</h3>
<p>With the project open, choose <b>Product → Clean Build Folder</b> or press <kbd>Shift</kbd> <kbd>Command</kbd> <kbd>K</kbd>. This removes the build products for that project and leaves the others alone.</p>

<h2 id="more">What else Xcode leaves behind</h2>
<div class="g-tbl"><table>
  <tr><th>What</th><th>Path</th><th>Safe to delete?</th></tr>
  <tr><td>iOS DeviceSupport</td><td><code>~/Library/Developer/Xcode/iOS DeviceSupport</code></td><td>Yes. Recreated when you connect a device.</td></tr>
  <tr><td>Xcode cache</td><td><code>~/Library/Caches/com.apple.dt.Xcode</code></td><td>Yes.</td></tr>
  <tr><td>Simulator devices</td><td><code>~/Library/Developer/CoreSimulator/Devices</code></td><td>Use the commands below. You lose apps and data installed in simulators.</td></tr>
  <tr><td>Archives</td><td><code>~/Library/Developer/Xcode/Archives</code></td><td>Keep archives of builds you shipped. They hold the symbols for crash reports.</td></tr>
</table></div>
<p>Remove simulators whose runtime is no longer installed:</p>
<pre><code>xcrun simctl delete unavailable</code></pre>
<p>List simulator runtimes and delete one you no longer test against (Xcode 15 or later):</p>
<pre><code>xcrun simctl runtime list
xcrun simctl runtime delete &lt;identifier&gt;</code></pre>
<p>You can also remove runtimes in Xcode → Settings → Components (called Platforms in Xcode 15).</p>
`,
    cta: {
      heading: "iClearer clears DerivedData with one tick",
      text: `<p>iClearer’s Builders screen shows Xcode DerivedData with its size, labelled <b>Safe</b> because Xcode rebuilds it. iOS Simulator data is listed too, labelled <b>Ask first</b>. What you clean goes to the Trash, and git repositories, signing keys and <code>.env</code> files can never be selected.</p>`,
    },
    faq: [
      {
        q: "Is it safe to delete Xcode DerivedData?",
        a: "Yes. DerivedData contains only files Xcode generates: build products, indexes, module caches and logs. Xcode recreates them on the next build. Your source code, project files and signing certificates are stored elsewhere.",
      },
      {
        q: "Where is Xcode DerivedData located?",
        a: "In ~/Library/Developer/Xcode/DerivedData, unless you changed it in Xcode → Settings → Locations. Each project has its own folder inside.",
      },
      {
        q: "What happens after I delete DerivedData?",
        a: "The next build of each project is a full build, so it takes longer, and Xcode re-indexes the project and resolves Swift packages again. After that, build times return to normal.",
      },
      {
        q: "How often should I delete DerivedData?",
        a: "When you need the space or when Xcode shows build errors that a clean build does not fix. There is no need to delete it on a schedule, because it speeds up your builds.",
      },
      {
        q: "Does deleting DerivedData fix Xcode build errors?",
        a: "Often, yes. Stale module caches and indexes in DerivedData can cause errors that do not match your code. Deleting the folder forces Xcode to rebuild everything from scratch.",
      },
    ],
    related: ["free-up-disk-space-mac-developers", "docker-disk-space-mac", "clear-npm-cache-node-modules-mac"],
  },

  {
    slug: "docker-disk-space-mac",
    group: "dev",
    title: "Docker Taking Up Too Much Space on Mac? Fix It",
    h1: "Docker taking up too much space on Mac",
    card: "Reclaim Docker disk space",
    description:
      "Docker Desktop stores everything in one growing disk image on your Mac. See what is using the space and the safe commands to reclaim it, without losing data.",
    answer: `<p>Docker Desktop for Mac keeps all images, containers, volumes and build cache inside one disk image file, which grows as you use Docker. To reclaim space, see what is using it with <code>docker system df</code>, then remove what is unused with <code>docker system prune</code>. Add <code>-a</code> to also remove images no container is using. <b>Do not delete the disk image file by hand</b>: that removes everything, including volumes.</p>`,
    toc: [
      ["where", "Where Docker stores data on a Mac"],
      ["check", "See what is using the space"],
      ["prune", "Reclaim space safely"],
      ["shrink", "If the disk image does not shrink"],
      ["colima", "Colima"],
    ],
    body: `
<h2 id="where">Where Docker stores data on a Mac</h2>
<p>Docker Desktop runs a small Linux virtual machine, and everything Docker stores sits in that machine’s disk image:</p>
<pre><code>~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw</code></pre>
<p>The file is sparse, so Finder can show a size far larger than what it really uses. To see the real figure:</p>
<pre><code>du -h ~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw</code></pre>

<h2 id="check">See what is using the space</h2>
<pre><code>docker system df</code></pre>
<p>This shows the space used by images, containers, local volumes and build cache, and how much of each is reclaimable. Add <code>-v</code> for a line-by-line list.</p>

<h2 id="prune">Reclaim space safely</h2>
<p>Work down this list and stop when you have enough space back.</p>
<div class="g-tbl"><table>
  <tr><th>Command</th><th>Removes</th><th>Risk</th></tr>
  <tr><td><code>docker builder prune</code></td><td>Build cache</td><td>None. Next builds are slower.</td></tr>
  <tr><td><code>docker container prune</code></td><td>Stopped containers</td><td>You lose anything written inside those containers.</td></tr>
  <tr><td><code>docker image prune</code></td><td>Dangling images (untagged)</td><td>None.</td></tr>
  <tr><td><code>docker image prune -a</code></td><td>Every image not used by a container</td><td>Images are pulled or built again when needed.</td></tr>
  <tr><td><code>docker system prune</code></td><td>Stopped containers, unused networks, dangling images, build cache</td><td>Low.</td></tr>
  <tr><td><code>docker volume prune</code></td><td>Unused anonymous volumes (add <code>-a</code> for named ones)</td><td>High. Volumes hold database data that cannot be rebuilt.</td></tr>
</table></div>
<p class="g-note"><b>Careful:</b> <code>docker system prune -a --volumes</code> does all of the above at once. Check <code>docker volume ls</code> first, and do not run it if a stopped container owns data you need.</p>

<h2 id="shrink">If the disk image does not shrink</h2>
<p>Docker Desktop hands freed space back to macOS, but it can take a little while after a prune. If the file is still large:</p>
<ul>
  <li>Restart Docker Desktop and check again with <code>du -h</code>, not Finder.</li>
  <li>Lower the disk limit in <b>Docker Desktop → Settings → Resources</b>. Reducing the limit deletes the disk image and everything in it, so only do this if you can rebuild or pull everything again.</li>
  <li>To start completely fresh, use <b>Troubleshoot → Clean / Purge data</b> in Docker Desktop. This removes all images, containers and volumes.</li>
</ul>

<h2 id="colima">Colima</h2>
<p>Colima keeps its virtual machine disks in <code>~/.colima</code>. The same <code>docker</code> prune commands work. To remove a Colima machine and its disk entirely:</p>
<pre><code>colima delete</code></pre>
`,
    cta: {
      heading: "See Docker next to your other developer files",
      text: `<p>iClearer’s Builders screen lists Colima and Docker folders in your home folder with their sizes, labelled <b>Ask first</b> because they can hold data that cannot be rebuilt. For Docker Desktop’s disk image, use the Docker commands above. iClearer also clears the caches that sit beside Docker on most developer Macs: Xcode DerivedData, npm, pnpm, Yarn, pip, Homebrew and Gradle.</p>`,
    },
    faq: [
      {
        q: "Why is Docker taking up so much space on my Mac?",
        a: "Docker Desktop stores every image, container, volume and build cache layer in one disk image file, and the file grows as you pull and build. Old images and build cache are usually the largest part. Run docker system df to see the breakdown.",
      },
      {
        q: "Is it safe to run docker system prune?",
        a: "Yes for most setups. It removes stopped containers, unused networks, dangling images and build cache. It does not remove volumes or tagged images unless you add --volumes or -a.",
      },
      {
        q: "Where is Docker.raw on a Mac?",
        a: "In ~/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw. It is a sparse file, so Finder may show its maximum size. Run du -h on the file to see how much disk space it really uses.",
      },
      {
        q: "Can I delete Docker.raw?",
        a: "Only if you want to lose everything in Docker. Deleting the file removes all images, containers and volumes. Use docker system prune, or Clean / Purge data in Docker Desktop, instead.",
      },
      {
        q: "Does docker system prune delete volumes?",
        a: "No, not by default. Volumes are only removed if you add the --volumes flag or run docker volume prune. Volumes often hold database data, so check docker volume ls before removing them.",
      },
    ],
    related: ["free-up-disk-space-mac-developers", "delete-xcode-derived-data", "clear-npm-cache-node-modules-mac"],
  },

  {
    slug: "clear-npm-cache-node-modules-mac",
    group: "dev",
    title: "Clear npm Cache and node_modules on Mac",
    h1: "How to clear npm cache and node_modules on Mac",
    card: "Clear npm cache and node_modules",
    description:
      "Free up disk space from Node.js on a Mac: clear the npm, pnpm, Yarn and Bun caches, find and delete old node_modules folders, and remove old Node versions.",
    answer: `<p>To clear the npm cache on a Mac, run <code>npm cache clean --force</code>. The cache lives in <code>~/.npm</code> and is safe to delete; npm downloads packages again when you next install. Old <code>node_modules</code> folders usually take far more space than the cache. Find them with:</p>
<pre><code>find ~ -name node_modules -type d -prune -exec du -sh {} + 2>/dev/null | sort -h | tail -20</code></pre>`,
    toc: [
      ["npm", "npm cache"],
      ["others", "pnpm, Yarn and Bun"],
      ["node-modules", "Find and delete node_modules"],
      ["versions", "Old Node versions"],
    ],
    body: `
<h2 id="npm">npm cache</h2>
<p>See how big it is:</p>
<pre><code>du -sh ~/.npm</code></pre>
<p>Clear it:</p>
<pre><code>npm cache clean --force</code></pre>
<p>npm asks for <code>--force</code> because the cache repairs itself and rarely needs clearing for correctness. Clearing it to get disk space back is fine. To remove only what is no longer needed and check the rest:</p>
<pre><code>npm cache verify</code></pre>

<h2 id="others">pnpm, Yarn and Bun</h2>
<div class="g-tbl"><table>
  <tr><th>Tool</th><th>Clear command</th><th>Find the folder</th></tr>
  <tr><td>pnpm</td><td><code>pnpm store prune</code></td><td><code>pnpm store path</code></td></tr>
  <tr><td>Yarn 1</td><td><code>yarn cache clean</code></td><td><code>yarn cache dir</code></td></tr>
  <tr><td>Yarn 2 and later</td><td><code>yarn cache clean --all</code></td><td><code>yarn config get cacheFolder</code></td></tr>
  <tr><td>Bun</td><td><code>bun pm cache rm</code></td><td><code>bun pm cache</code></td></tr>
</table></div>
<p><code>pnpm store prune</code> only removes packages that no project on your Mac still uses, so it is safe to run at any time.</p>

<h2 id="node-modules">Find and delete node_modules</h2>
<p>Every project has its own <code>node_modules</code> folder, often several hundred megabytes. Projects you finished long ago still have theirs. List the 20 largest:</p>
<pre><code>find ~ -name node_modules -type d -prune -exec du -sh {} + 2>/dev/null | sort -h | tail -20</code></pre>
<p>Delete one by its path:</p>
<pre><code>rm -rf ~/code/old-project/node_modules</code></pre>
<p>To delete every <code>node_modules</code> folder under one projects folder, move into it first:</p>
<pre><code>cd ~/code
find . -name node_modules -type d -prune -exec rm -rf {} +</code></pre>
<p class="g-note"><b>Careful:</b> the last command deletes without asking. Run it only inside a folder of your own projects, never in your home folder, because some installed apps and tools keep a <code>node_modules</code> folder they need.</p>
<p>Deleting <code>node_modules</code> is safe for your own projects. Run <code>npm install</code>, <code>pnpm install</code> or <code>yarn</code> in the project to bring it back.</p>

<h2 id="versions">Old Node versions</h2>
<p>If you use nvm, each installed Node version is kept in <code>~/.nvm/versions</code>. List them and remove the ones you no longer need:</p>
<pre><code>nvm ls
nvm uninstall 16</code></pre>
`,
    cta: {
      heading: "iClearer finds the npm, pnpm and Yarn caches for you",
      text: `<p>iClearer’s Builders screen shows the npm cache, pnpm store and Yarn cache with their sizes, labelled <b>Safe</b> because your package manager downloads what it needs again. What you clean goes to the Trash. Git repositories, <code>.env</code> files and API tokens can never be selected.</p>`,
    },
    faq: [
      {
        q: "Is it safe to clear the npm cache?",
        a: "Yes. The npm cache in ~/.npm holds downloaded package files. After you clear it with npm cache clean --force, npm downloads packages again the next time you install them. Your projects are not affected.",
      },
      {
        q: "Where is the npm cache on a Mac?",
        a: "In ~/.npm, with the package data in ~/.npm/_cacache. Run npm config get cache to confirm the location on your Mac.",
      },
      {
        q: "Is it safe to delete node_modules?",
        a: "Yes, for your own projects. node_modules contains installed dependencies that are listed in package.json. Run npm install, pnpm install or yarn in the project folder to recreate it.",
      },
      {
        q: "How do I find all node_modules folders on my Mac?",
        a: "Run find ~ -name node_modules -type d -prune in Terminal. Add -exec du -sh {} + to see the size of each one.",
      },
      {
        q: "Why does npm cache clean need --force?",
        a: "npm’s cache checks and repairs itself, so npm treats clearing it as unnecessary for fixing problems and asks you to confirm with --force. Clearing it to free disk space is a normal use.",
      },
    ],
    related: ["free-up-disk-space-mac-developers", "delete-xcode-derived-data", "docker-disk-space-mac"],
  },

  {
    slug: "delete-ollama-models-mac",
    group: "dev",
    title: "Delete Ollama Models on Mac and Free Up Space",
    h1: "How to delete Ollama models on Mac",
    card: "Delete Ollama and local AI models",
    description:
      "Local AI models are often the largest files on a Mac. See where Ollama, LM Studio and Hugging Face store models, how to delete them, and how to move them.",
    answer: `<p>Ollama stores models on a Mac in <code>~/.ollama/models</code>. To delete one, run <code>ollama list</code> to see each model and its size, then <code>ollama rm</code> followed by the model name, for example <code>ollama rm llama3.2</code>. Models are safe to delete. To use one again you download it again with <code>ollama pull</code>.</p>`,
    toc: [
      ["ollama", "Ollama"],
      ["move", "Move Ollama models to another drive"],
      ["lm-studio", "LM Studio"],
      ["hugging-face", "Hugging Face cache"],
    ],
    body: `
<h2 id="ollama">Ollama</h2>
<p>List your models with their sizes:</p>
<pre><code>ollama list</code></pre>
<p>Delete one:</p>
<pre><code>ollama rm llama3.2</code></pre>
<p>See the total on disk:</p>
<pre><code>du -sh ~/.ollama/models</code></pre>
<p>Use <code>ollama rm</code> rather than deleting files in Finder. Models share layers with each other, and Ollama only removes the files no other model still uses.</p>

<h2 id="move">Move Ollama models to another drive</h2>
<p>If you want to keep your models but not on the startup disk, set the <code>OLLAMA_MODELS</code> environment variable to a folder on an external drive. For the Ollama Mac app:</p>
<pre><code>launchctl setenv OLLAMA_MODELS /Volumes/External/ollama-models</code></pre>
<p>Quit and reopen Ollama afterwards. The setting lasts until you restart your Mac, so run the command again after a restart. Models you already downloaded stay in the old folder until you move or delete them.</p>

<h2 id="lm-studio">LM Studio</h2>
<p>LM Studio keeps models in <code>~/.lmstudio/models</code>. Older versions used <code>~/.cache/lm-studio/models</code>. Delete models from the <b>My Models</b> view in the app, which shows the size of each.</p>

<h2 id="hugging-face">Hugging Face cache</h2>
<p>Python libraries such as Transformers and Diffusers download models to <code>~/.cache/huggingface/hub</code>. Check the size:</p>
<pre><code>du -sh ~/.cache/huggingface</code></pre>
<p>Choose what to delete from an interactive list:</p>
<pre><code>huggingface-cli delete-cache</code></pre>
<p>Deleting the folder is also safe. Models download again when a script asks for them.</p>
`,
    cta: {
      heading: "iClearer shows what your AI tools are using",
      text: `<p>iClearer’s Builders screen lists Ollama models and the <code>~/.cache</code> folder with their sizes. Models are labelled <b>Ask first</b>, because getting one back means downloading it again. What you remove goes to the Trash, and API tokens and <code>.env</code> files can never be selected.</p>`,
    },
    faq: [
      {
        q: "Where does Ollama store models on a Mac?",
        a: "In ~/.ollama/models, inside your home folder. The blobs folder holds the model data and the manifests folder records which files belong to which model. You can change the location with the OLLAMA_MODELS environment variable.",
      },
      {
        q: "How do I delete an Ollama model?",
        a: "Run ollama list to see the installed models, then ollama rm followed by the name, for example ollama rm llama3.2. Ollama removes the model’s files unless another model still uses them.",
      },
      {
        q: "Is it safe to delete the ~/.ollama/models folder?",
        a: "Yes, but it removes every model at once. Nothing else breaks; you download models again with ollama pull. To remove just some models, use ollama rm instead.",
      },
      {
        q: "How much disk space do local AI models use?",
        a: "Usually between 2 GB and 50 GB each, depending on the model size and quantization. A few models can easily use more space than everything else in your home folder.",
      },
      {
        q: "Can I move Ollama models to an external drive?",
        a: "Yes. Set OLLAMA_MODELS to a folder on the external drive, for the Mac app with launchctl setenv OLLAMA_MODELS followed by the path, then restart Ollama. The drive must be connected whenever you use Ollama.",
      },
    ],
    related: ["free-up-disk-space-mac-developers", "docker-disk-space-mac", "find-large-files-mac"],
  },
];

export const CTA_NOTE = ICLEARER_FREE_NOTE;
