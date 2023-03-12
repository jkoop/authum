/**
 * @return void
 */
window.create = function () {
    let id = "new" + (new Date).getTime();
    let tr = document.createElement('tr'); // create new row
    document.querySelector('#permissions').appendChild(tr); // append it to the table
    document.querySelector('#permissions').insertBefore(tr, document.querySelector('#fallback')); // move the new row to before the old last row (the disabled one)

    // set the contents of the row
    tr.outerHTML = `<tr id="${id}">
        <td>
            <input name="${id}[regex]" type="text" maxLength="255" value="" required />
        </td>
        <td><select name="${id}[if_matches]">
                <option>pass</option>
                <option>fail</option>
            </select></td>
        <td><input name="${id}[comment]" type="text" maxLength="255" value="" /></td>
        <td>
            <button type="button" onClick="moveUp(this)">Up</button>
            <button type="button" onClick="moveDown(this)">Down</button>
            <button type="button" onClick="deleteRow(this)">Delete</button>
        </td>
    </tr>`;
};

/**
 * @param button Element
 * @return void
 */
window.moveUp = function (button) {
    let tr = button.closest('tr');
    let previous = tr.previousSibling;
    let parent = document.querySelector('#permissions');

    while (previous?.tagName?.toLowerCase() != 'tr') {
        if (!previous) return;
        previous = previous.previousSibling;
    }

    parent.removeChild(tr);
    parent.insertBefore(tr, previous);
};

/**
 * @param button Element
 * @return void
 */
window.moveDown = function (button) {
    let tr = button.closest('tr');
    let next = tr.nextSibling;
    let parent = document.querySelector('#permissions');

    while (next?.tagName?.toLowerCase() != 'tr') {
        if (!next) return;
        next = next.nextSibling;
    }

    next = next.nextSibling;

    while (next?.tagName?.toLowerCase() != 'tr') {
        if (!next) return;
        next = next.nextSibling;
    }

    parent.removeChild(tr);
    parent.insertBefore(tr, next);
};

/**
 * @param button Element
 * @return void
 */
window.deleteRow = function (button) {
    let tr = button.closest('tr');
    let regex = tr.querySelector('input').value;

    if (regex != '' && !confirm(`Really delete ${regex}?`)) return;

    tr.remove();
};
