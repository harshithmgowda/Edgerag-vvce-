const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
const React = require('react');

function load(relativePath, imports = {}) {
  const source = fs.readFileSync(path.join(__dirname, relativePath), 'utf8');
  const output = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.React, esModuleInterop: true },
  }).outputText;
  const exports = {};
  new Function('require', 'exports', output)(name => imports[name] ?? require(name), exports);
  return exports;
}

test('in-page confirmation supports sign-in, cancellation, retry and duplicate prevention', async () => {
  const previousStorage = global.localStorage;
  try {
    for (const kind of ['equipment', 'manual']) {
      let calls = 0, removed = 0, finish, reject, opened = 0, closed = 0;
      let stateIndex = 0, refIndex = 0;
      const states = [], refs = [], messages = [], stored = {};
      global.localStorage = { getItem: key => stored[key] ?? null, setItem: (key, value) => { stored[key] = value; } };
      class ApiError extends Error { constructor(message, status) { super(message); this.status = status; } }
      const remove = () => { calls++; return new Promise((resolve, fail) => { finish = resolve; reject = fail; }); };
      const { DeleteRecordButton } = load('../components/DeleteRecordButton.tsx', {
        react: { ...React,
          useId: () => 'delete-title',
          useState: value => { const i = stateIndex++; if (!(i in states)) states[i] = value; return [states[i], next => { states[i] = next; }]; },
          useRef: value => { const i = refIndex++; return refs[i] ??= { current: value === null ? { showModal: () => opened++, close: () => closed++ } : value }; },
        },
        'lucide-react': { Trash2: () => null },
        '@/lib/api-client': { ApiError, api: { deleteEquipment: remove, deleteManual: remove,
          login: async () => ({ user: {role: 'ADMIN'}, access_token: 'token' }) } },
      });
      function render() {
        stateIndex = 0; refIndex = 0;
        return DeleteRecordButton({ kind, id: 'asset-1', name: 'Pump', onDeleted: () => removed++, onMessage: text => messages.push(text) });
      }
      function nodes(node) {
        if (!node || typeof node !== 'object') return [];
        return [node, ...React.Children.toArray(node.props?.children).flatMap(nodes)];
      }
      function button(tree, text) { return nodes(tree).find(n => n.type === 'button' && n.props.children === text); }
      let tree = render();
      await tree.props.children[0].props.onClick();
      assert.equal(opened, 1);
      assert.equal(calls, 0);
      tree = render();
      assert.ok(nodes(tree).some(n => n.type === 'form'));
      button(tree, 'Cancel').props.onClick();
      assert.equal(closed, 1);
      assert.equal(calls, 0);
      tree.props.children[0].props.onClick();
      tree = render();
      await nodes(tree).find(n => n.type === 'form').props.onSubmit({ preventDefault() {} });
      tree = render();
      assert.equal(calls, 0, 'sign-in must not automatically delete');
      const request = button(tree, 'Delete permanently').props.onClick();
      await button(tree, 'Delete permanently').props.onClick();
      assert.equal(calls, 1);
      reject(new ApiError('Expired', 401));
      await request;
      tree = render();
      assert.ok(nodes(tree).some(n => n.type === 'form'), 'expired session returns to sign-in');
      await nodes(tree).find(n => n.type === 'form').props.onSubmit({ preventDefault() {} });
      tree = render();
      const retry = button(tree, 'Delete permanently').props.onClick();
      finish({ deleted: true, cleanup_pending: 1 });
      await retry;
      assert.equal(removed, 1);
      assert.match(messages.at(-1), /cleanup needs administrator/);
    }
  } finally { global.localStorage = previousStorage; }
});
test('delete API sends authenticated DELETE and surfaces server errors', async () => {
  const previousFetch = global.fetch;
  const previousWindow = global.window;
  const previousStorage = global.localStorage;
  try {
    global.window = {};
    global.localStorage = { getItem: () => 'test-token' };
    const { api } = load('api-client.ts');
    for (const [method, endpoint] of [['deleteEquipment', 'equipment'], ['deleteManual', 'manuals']]) {
      global.fetch = async (url, options) => {
        assert.ok(url.endsWith('/' + endpoint + '/asset-1'));
        assert.equal(options.method, 'DELETE');
        assert.equal(options.headers.Authorization, 'Bearer test-token');
        return new Response('{"deleted":true,"cleanup_pending":0}', { status: 200 });
      };
      assert.equal((await api[method]('asset-1')).deleted, true);
      global.fetch = async () => new Response('{"detail":"Administrator required"}', { status: 403 });
      await assert.rejects(api[method]('asset-1'), /Administrator required/);
    }
  } finally {
    global.fetch = previousFetch; global.window = previousWindow; global.localStorage = previousStorage;
  }
});

