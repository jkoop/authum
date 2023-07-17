<!DOCTYPE html>
<html lang="en-CA">

<head>
    <?php view('head', ['title' => 'Access-Control List']) ?>
    <style>
        thead th {
            border-left: 1px solid black;
            border-right: 1px solid black;
        }

        tbody td {
            white-space: nowrap;
        }
    </style>
    <script>
        function setTheFieldNames() {
            document.querySelectorAll('input[name=delete]').forEach(input => {
                if (!input.checked) return;
                input.closest('tr').remove();
            });

            let counter = 0;
            document.querySelectorAll('tbody tr').forEach(tr => {
                tr.querySelectorAll('select, input').forEach(field => {
                    if (field.name != "") {
                        field.name = `${counter}[${field.name}]`;
                    }
                });
                counter++;
            });
        }

        function addNew() {
            let newTr = document.querySelector('tbody tr:last-of-type').cloneNode(true);
            newTr.querySelectorAll('select, input, button').forEach(field => {
                field.removeAttribute('disabled');
            })
            document.querySelector('tbody').insertBefore(newTr, document.querySelector('tbody tr:last-of-type'));
        }

        function moveUp(button) {
            let tr = button.closest('tr');
            let previous = tr.previousSibling;

            while ((previous.tagName ?? '') != 'TR') {
                previous = previous.previousSibling;
                if (previous == null) return;
            }

            document.querySelector('tbody').insertBefore(tr, previous);
        }

        function moveDown(button) {
            let tr = button.closest('tr');
            let next = tr.nextSibling;

            while ((next.tagName ?? '') != 'TR') {
                next = next.nextSibling;
                if (next == null) return;
            }

            next = next.nextSibling;

            while ((next.tagName ?? '') != 'TR') {
                next = next.nextSibling;
                if (next == null) return;
            }

            document.querySelector('tbody').insertBefore(tr, next);
        }
    </script>
</head>

<body>
    <h1>Access-Control List</h1>
    <?php view('navigation') ?>

    <p>When a forward auth request is made, the rules in this ACL are compared one-by-one in order from top to bottom. The first rule to match determines the allowed-ness (allow/deny). The method "HEAD" will be processed as if it is "GET". Paths never begin with a slash.</p>

    <form method="post" onSubmit="setTheFieldNames()">
        <table>
            <thead>
                <tr>
                    <th colspan="2">Service(s)</th>
                    <th colspan="2">User(s)</th>
                    <th colspan="2">Request Method <a href="https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods" target="_blank">(?)</a></th>
                    <th colspan="2">Path</th>
                    <th colspan="2">Query String <a href="https://en.wikipedia.org/wiki/Query_string" target="_blank">(?)</a></th>
                    <th>If Matches</th>
                    <th>Comment</th>
                    <td><button type="button" onclick="addNew()">add new</button></td>
                </tr>
            </thead>
            <tbody>
                <?php foreach (DB::query('SELECT * FROM acl ORDER BY `order`') as $rule) : ?>
                    <tr>
                        <td><select name="service_invert">
                                <option value="0" <?= $rule['service_invert'] ? '' : 'selected' ?>>Is</option>
                                <option value="1" <?= $rule['service_invert'] ? 'selected' : '' ?>>Is not</option>
                            </select></td>
                        <td><select name="service">
                                <option value=""><i>-- any --</i></option>
                                <optgroup label="groups">
                                    <?php view('options-service-group', ['selected' => $rule['service_group_id']]) ?>
                                </optgroup>
                                <optgroup label="services">
                                    <?php view('options-service', ['selected' => $rule['service_id']]) ?>
                                </optgroup>
                            </select></td>
                        <td><select name="user_invert">
                                <option value="0" <?= $rule['user_invert'] ? '' : 'selected' ?>>Is</option>
                                <option value="1" <?= $rule['user_invert'] ? 'selected' : '' ?>>Is not</option>
                            </select></td>
                        <td><select name="user">
                                <option value=""><i>-- any --</i></option>
                                <optgroup label="groups">
                                    <?php view('options-user-group', ['selected' => $rule['user_group_id']]) ?>
                                </optgroup>
                                <optgroup label="users">
                                    <?php view('options-user', ['selected' => $rule['user_id']]) ?>
                                </optgroup>
                            </select></td>
                        <td><select name="method_regex_invert">
                                <option value="0" <?= $rule['method_regex_invert'] ? '' : 'selected' ?>>Matches</option>
                                <option value="1" <?= $rule['method_regex_invert'] ? 'selected' : '' ?>>Doesn't match</option>
                            </select></td>
                        <td><input name="method_regex" maxlength="255" value="<?= $rule['method_regex'] ?>" placeholder="mysql regex" /></td>
                        <td><select name="path_regex_invert">
                                <option value="0" <?= $rule['path_regex_invert'] ? '' : 'selected' ?>>Matches</option>
                                <option value="1" <?= $rule['path_regex_invert'] ? 'selected' : '' ?>>Doesn't match</option>
                            </select>
                        </td>
                        <td><input name="path_regex" maxlength="255" value="<?= $rule['path_regex'] ?>" placeholder="mysql regex" /></td>
                        <td><select name="query_string_regex_invert">
                                <option value="0" <?= $rule['query_string_regex_invert'] ? '' : 'selected' ?>>Matches</option>
                                <option value="1" <?= $rule['query_string_regex_invert'] ? 'selected' : '' ?>>Doesn't match</option>
                            </select>
                        </td>
                        <td><input name="query_string_regex" maxlength="255" value="<?= $rule['query_string_regex'] ?>" placeholder="mysql regex" /></td>
                        <td><select name="if_matches">
                                <option <?= $rule['if_matches'] == 'allow' ? 'selected' : '' ?>>allow</option>
                                <option <?= $rule['if_matches'] == 'deny' ? 'selected' : '' ?>>deny</option>
                            </select>
                        </td>
                        <td><input name="comment" maxlength="255" value="<?= $rule['comment'] ?>" /></td>
                        <td>
                            <button type="button" onclick="moveUp(this)">^</button>
                            <button type="button" onclick="moveDown(this)">v</button>
                            <label><input name="delete" type="checkbox" /> delete?</label>
                        </td>
                    </tr>
                <?php endforeach ?>
                <tr>
                    <td><select name="service_invert" disabled>
                            <option value="0">Is</option>
                            <option value="1">Is not</option>
                        </select></td>
                    <td><select name="service" disabled>
                            <option value=""><i>-- any --</i></option>
                            <optgroup label="groups">
                                <?php view('options-service-group') ?>
                            </optgroup>
                            <optgroup label="services">
                                <?php view('options-service') ?>
                            </optgroup>
                        </select></td>
                    <td><select name="user_invert" disabled>
                            <option value="0">Is</option>
                            <option value="1">Is not</option>
                        </select></td>
                    <td><select name="user" disabled>
                            <option value=""><i>-- any --</i></option>
                            <optgroup label="groups">
                                <?php view('options-user-group') ?>
                            </optgroup>
                            <optgroup label="users">
                                <?php view('options-user') ?>
                            </optgroup>
                        </select></td>
                    <td><select name="method_regex_invert" disabled>
                            <option value="0">Matches</option>
                            <option value="1">Doesn't match</option>
                        </select></td>
                    <td><input name="method_regex" maxlength="255" placeholder="mysql regex" disabled /></td>
                    <td><select name="path_regex_invert" disabled>
                            <option value="0">Matches</option>
                            <option value="1">Doesn't match</option>
                        </select>
                    </td>
                    <td><input name="path_regex" maxlength="255" placeholder="mysql regex" disabled /></td>
                    <td><select name="query_string_regex_invert" disabled>
                            <option value="0">Matches</option>
                            <option value="1">Doesn't match</option>
                        </select>
                    </td>
                    <td><input name="query_string_regex" maxlength="255" placeholder="mysql regex" disabled /></td>
                    <td><select name="if_matches" disabled>
                            <option>allow</option>
                            <option selected>deny</option>
                        </select>
                    </td>
                    <td><input name="comment" maxlength="255" disabled /></td>
                    <td>
                        <button type="button" onclick="moveUp(this)" disabled>^</button>
                        <button type="button" onclick="moveDown(this)" disabled>v</button>
                        <label><input name="delete" type="checkbox" disabled /> delete?</label>
                    </td>
                </tr>
            </tbody>
        </table>
        <button type="submit">Save</button>
    </form>

    <?php view('logged-in-footer') ?>
</body>

</html>
