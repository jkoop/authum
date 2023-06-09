<?php

/** This plugin replaces UNIX timestamps with human-readable dates in your local timezone.
 * Mouse click on the date field reveals timestamp back.
 *
 * @link https://www.adminer.org/plugins/#use
 * @author Anonymous
 * @license http://www.apache.org/licenses/LICENSE-2.0 Apache License, Version 2.0
 * @license http://www.gnu.org/licenses/gpl-2.0.html GNU General Public License, version 2 (one or other)
 */
class AdminerReadableDates {
    function head() {
        echo <<<HTML
            <style>
                td.readableDate {
                    text-align: right;
                }
                td.readableDate:hover {
                    text-align: left;
                }
                td.readableDate span.rawDate,
                td.readableDate:hover span.readableDate {
                    display: none;
                }
                td.readableDate span.readableDate {
                    font-style: italic;
                }
                td.readableDate:hover span.rawDate {
                    display: initial;
                }
            </style>
        HTML, script(<<<JAVASCRIPT
            document.addEventListener('DOMContentLoaded', function(event) {
                var date = new Date();
                var tds = document.querySelectorAll('td[id^="val"]');
                for (var i = 0; i < tds.length; i++) {
                    var text = tds[i].innerHTML.trim();
                    if (text.match(/^\d{10}(\.\d+)?$/)) {
                        date.setTime(parseInt(text) * 1000);
                        // add timezone to column header
                        let columnHeader = document.getElementById('th[' + tds[i].id.split('[').slice(-1)[0]);
                        columnHeader.querySelector('.timezone')?.remove(); // in case we've already been here
                        columnHeader.innerHTML = columnHeader.innerHTML.trim();
                        columnHeader.innerHTML += ' <span class="timezone" style="font-style: italic; font-weight: normal">' + Intl.DateTimeFormat().resolvedOptions().timeZone;
                        // add formatted time to td
                        tds[i].classList.add('readableDate');
                        tds[i].innerHTML =
                            '<span class="rawDate">' + tds[i].innerHTML.trim() + '</span>' +
                            '<span class="readableDate">' +
                                [
                                    'Jan',
                                    'Feb',
                                    'Mar',
                                    'Apr',
                                    'May',
                                    'Jun',
                                    'Jul',
                                    'Aug',
                                    'Sep',
                                    'Oct',
                                    'Nov',
                                    'Dec',
                                ][date.getMonth()] + ' ' +
                                ("" + date.getDay()).padStart(2, "0") + ', ' +
                                date.getFullYear() + ', ' +
                                ("" + (date.getHours() % 12 == 0 ? 12 : date.getHours() % 12)).padStart(2, "0") + ':' +
                                ("" + date.getMinutes()).padStart(2, "0") + ':' +
                                ("" + date.getSeconds()).padStart(2, "0") +
                                (text.includes('.') ? '.' + text.split('.')[1] : '') +
                                ' ' + (date.getHours() >= 12 ? 'pm' : 'am') +
                            '</span>';
                    }
                }
            });
        JAVASCRIPT);
    }
}
