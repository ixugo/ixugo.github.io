---
title: React 基础
description: 
date: 2020-04-10 15:00:00
slug: 
image: 
draft: false
categories:
    - React
tags:
    - React
---





# React 开发基础



### 1.0 受控组件

![image-20200327000328421](http://img.golang.space/PicGo/03/27-00:03:29-2020-image-20200327000328421.png)



### 1.1 父组件向子组件单向传值

```js
renderSquare(i) {
    return <Square value={i}/>;
}
```

子组件 Square

```jsx
class Square extends React.Component {
  render() {
    return <button className="square">{this.props.value}</button>;
  }
}
```

说明: 父组件使用属性方式传值过去, 子组件直接 props 接收



### 1.2 子组件向父组件传值

子组件通过 props 调用 父类的方法, 将数据通过方法参数传递过去

```jsx
<button className="square" onClick={() => this.props.onClick.bind(this, this.state.value)}>
  {this.props.value}
</button>
```

父组件, 调用子组件时传递函数

```jsx
renderSquare(i) {
  return (
    <Square value={this.state.squares[i]} onClick={() => this.handleClick(i)} />
  );

handleClick(i) {
  const squares = this.state.squares.slice();
  squares[i] = 'X';
  this.setState({squares: squares});
}


```

注意在 `handleClick` 方法中调用了 `slice` 方法进行数组赋值, 为什么要这么做, 而不是在原数组中改变呢?

不直接在源数据上修改, 可以跟踪到数据的改变 , 同时确定了

1.2 函数组件

```jsx
function Square(props) {
  return (
    <button className="square" onClick={props.onClick}>
      {props.value}
    </button>
  );
}
```



### 1.2 如何阻止默认行为

```jsx
function ActionLink() {
  function handleClick(e) {
    e.preventDefault(); // 阻止默认行为
    console.log('The link was clicked.');
  }

  return (
    <a href="#" onClick={handleClick}>
      Click me
    </a>
  );
}
```



### 1.3 函数事件绑定

```jsx
class Toggle extends React.Component {
  constructor(props) {
    super(props);
    this.state = { isToggleOn: true };

    // 为了在回调中使用 `this`，这个绑定是必不可少的
    this.handleClick = this.handleClick.bind(this);
  }

  handleClick() {
    this.setState(state => ({
      isToggleOn: !state.isToggleOn
    }));
  }

  render() {
    return <button onClick={this.handleClick}>{this.state.isToggleOn ? 'ON' : 'OFF'}</button>;
  }
}
```

通常情况下，如果你没有在方法后面添加 `()`，例如 `onClick={this.handleClick}`，你应该为这个方法绑定 `this`。

向事件处理程序传递参数, 两种方式等价

```jsx
<button onClick={(e) => this.deleteRow(id, e)}>Delete Row</button>     // 显式传递
<button onClick={this.deleteRow.bind(this, id)}>Delete Row</button>    // 隐式传递
```



### 1.4 使用条件运算符条件渲染

#### 1.4.1 IF

```jsx
function Greeting(props) {
  const isLoggedIn = props.isLoggedIn;
  if (isLoggedIn) {
    return <UserGreeting />;
  }
  return <GuestGreeting />;
}
```

#### 1.4.2 &&

```jsx
function Mailbox(props) {
  const unreadMessages = props.unreadMessages;
  return (
    <div>
      <h1>Hello!</h1>
      {unreadMessages.length > 0 && <h2>You have {unreadMessages.length} unread messages.</h2>}
    </div>
  );
}
```

#### 1.4.3 阻止渲染 return

```jsx
function WarningBanner(props) {
  if (!props.warn) {
    return null;
  }

  return <div className="warning">Warning!</div>;
}

class Page extends React.Component {
  constructor(props) {
    super(props);
    this.state = { showWarning: true };
    this.handleToggleClick = this.handleToggleClick.bind(this);
  }

  handleToggleClick() {
    this.setState(state => ({
      showWarning: !state.showWarning
    }));
  }

  render() {
    return (
      <div>
        <WarningBanner warn={this.state.showWarning} />
        <button onClick={this.handleToggleClick}>{this.state.showWarning ? 'Hide' : 'Show'}</button>
      </div>
    );
  }
}
```



### 1.5 生命周期

```jsx
componentDidMount(){}      // 渲染后
componentDidUpdate(){}     //  更新时
componentWillUnmount(){}   // 销毁时
```



### 1.6 列表

列表需要制定 key 值, key 唯一. 当不指定时默认以下标作为 key , 会出现警告提示

key 应在数组上下文中指定

```js
function ListItem(props) {
  // 正确！这里不需要指定 key：
  return <li>{props.value}</li>;
}

function NumberList(props) {
  const numbers = props.numbers;
  const listItems = numbers.map(number => (
    // 正确！key 应该在数组的上下文中被指定
    <ListItem key={number.toString()} value={number} />
  ));
  return <ul>{listItems}</ul>;
}
```



### 1.7 表单-受控组件

https://zh-hans.reactjs.org/docs/forms.html

#### 1.7.1 input

```jsx
class NameForm extends React.Component {
  constructor(props) {
    super(props);
    this.state = { value: '' };

    this.handleChange = this.handleChange.bind(this);
    this.handleSubmit = this.handleSubmit.bind(this);
  }

  handleChange(event) {
    this.setState({ value: event.target.value });
  }

  handleSubmit(event) {
    alert('提交的名字: ' + this.state.value);
    event.preventDefault();
  }

  render() {
    return (
      <form onSubmit={this.handleSubmit}>
        <label>
          名字:
          <input type="text" value={this.state.value} onChange={this.handleChange} />
        </label>
        <input type="submit" value="提交" />
      </form>
    );
  }
}
```

#### 1.7.2 textarea

```jsx
class EssayForm extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      value: '请撰写一篇关于你喜欢的 DOM 元素的文章.'
    };

    this.handleChange = this.handleChange.bind(this);
    this.handleSubmit = this.handleSubmit.bind(this);
  }

  handleChange(event) {
    this.setState({ value: event.target.value });
  }

  handleSubmit(event) {
    alert('提交的文章: ' + this.state.value);
    event.preventDefault();
  }

  render() {
    return (
      <form onSubmit={this.handleSubmit}>
        <label>
          文章:
          <textarea value={this.state.value} onChange={this.handleChange} />
        </label>
        <input type="submit" value="提交" />
      </form>
    );
  }
}
```

#### 1.7.3 select

```jsx
class FlavorForm extends React.Component {
  constructor(props) {
    super(props);
    this.state = { value: 'coconut' };

    this.handleChange = this.handleChange.bind(this);
    this.handleSubmit = this.handleSubmit.bind(this);
  }

  handleChange(event) {
    this.setState({ value: event.target.value });
  }

  handleSubmit(event) {
    alert('你喜欢的风味是: ' + this.state.value);
    event.preventDefault();
  }

  render() {
    return (
      <form onSubmit={this.handleSubmit}>
        <label>
          选择你喜欢的风味:
          <select value={this.state.value} onChange={this.handleChange}>
            <option value="grapefruit">葡萄柚</option>
            <option value="lime">酸橙</option>
            <option value="coconut">椰子</option>
            <option value="mango">芒果</option>
          </select>
        </label>
        <input type="submit" value="提交" />
      </form>
    );
  }
}
```



## 1.8 约定: 自定义组件以大写字母开头
react 认为小写的 tag 是原生 dom 节点
大写字母开头为自定义组件



## 1.9 生命周期

![image-20200329222945851](http://img.golang.space/PicGo/2020-04-01/16-56-27-image-20200329222945851.png)





+ `getDerivedStateFromProp`  适合表单初始化
+ `componentDidMount` 适合资源加载, 发起 ajax 请求
+ `componeWillUnmount` 组件移除时调用, 释放资源
+ `getSnapshotBeforeUpdate` render 之前调用, 获取 render 之前的状态
+ `componentDidUpdate` ui 更新时被调用, 页面需要 prop 变化时重新获取数据
+ `showldComponentUpdate` 性能优化



### 1.9.1 demo 来了新消息保证位置不变

新数据会重新渲染界面, 就会导致高度不断增加, 滚动条根据消息变化, 在 render 之前获取高度, 更新时加上差值

![image-20200329233917546](http://img.golang.space/PicGo/2020-04-01/16-57-03-image-20200329233917546.png)





![](http://img.golang.space/PicGo/2020-04-01/16-57-26-image-20200329225734894.png)



![image-20200329225750606](http://img.golang.space/PicGo/2020-04-01/16-57-32-image-20200329225750606.png)



![image-20200329225850085](http://img.golang.space/PicGo/2020-04-01/16-57-37-image-20200329225850085.png)



![image-20200329225940540](http://img.golang.space/PicGo/2020-04-01/16-57-42-image-20200329225940540.png)

![image-20200329230148165](http://img.golang.space/PicGo/2020-04-01/16-57-47-image-20200329230148165.png)





## 2 HOOK

```bash
import React,{useState} from 'react';

const [count,setCount] = useState(0);

render(){
	return (
		<h2>{count} </h2>
		<buttton onClick={ ()=>setCount(count+1) }> change</button>
	);
}

```









# ANT



### 1.0 安装

```bash
npm create umi
// 选择模板 app
// 空格选择功能,
npm install
npm run start
```





# Typescript 语法

### 1.0 安装

```bash
sudo npm i typescript -g
```

### 1.3 函数事件绑定

```jsx
class Toggle extends React.Component {
  constructor(props) {
    super(props);
    this.state = { isToggleOn: true };

    // 为了在回调中使用 `this`，这个绑定是必不可少的
    this.handleClick = this.handleClick.bind(this);
  }

  handleClick() {
    this.setState(state => ({
      isToggleOn: !state.isToggleOn
    }));
  }

  render() {
    return <button onClick={this.handleClick}>{this.state.isToggleOn ? 'ON' : 'OFF'}</button>;
  }
}
```

通常情况下，如果你没有在方法后面添加 `()`，例如 `onClick={this.handleClick}`，你应该为这个方法绑定 `this`。

向事件处理程序传递参数, 两种方式等价

```jsx
<button onClick={(e) => this.deleteRow(id, e)}>Delete Row</button>     // 显式传递
<button onClick={this.deleteRow.bind(this, id)}>Delete Row</button>    // 隐式传递
```

### 1.4 使用条件运算符条件渲染

#### 1.4.1 IF

```jsx
function Greeting(props) {
  const isLoggedIn = props.isLoggedIn;
  if (isLoggedIn) {
    return <UserGreeting />;
  }
  return <GuestGreeting />;
}
```

### 1.4.2 &&

```jsx
function Mailbox(props) {
  const unreadMessages = props.unreadMessages;
  return (
    <div>
      <h1>Hello!</h1>
      {unreadMessages.length > 0 && <h2>You have {unreadMessages.length} unread messages.</h2>}
    </div>
  );
}
```

#### 1.4.3 阻止渲染 return

```jsx
function WarningBanner(props) {
  if (!props.warn) {
    return null;
  }

  return <div className="warning">Warning!</div>;
}

class Page extends React.Component {
  constructor(props) {
    super(props);
    this.state = { showWarning: true };
    this.handleToggleClick = this.handleToggleClick.bind(this);
  }

  handleToggleClick() {
    this.setState(state => ({
      showWarning: !state.showWarning
    }));
  }

  render() {
    return (
      <div>
        <WarningBanner warn={this.state.showWarning} />
        <button onClick={this.handleToggleClick}>{this.state.showWarning ? 'Hide' : 'Show'}</button>
      </div>
    );
  }
}
```

### 1.5 生命周期

```jsx
componentDidMount(){}      // 渲染后
componentDidUpdate(){}     //  更新时
componentWillUnmount(){}   // 销毁时
```

### 1.6 列表

列表需要制定 key 值, key 唯一. 当不指定时默认以下标作为 key , 会出现警告提示

key 应在数组上下文中指定

```js
function ListItem(props) {
  // 正确！这里不需要指定 key：
  return <li>{props.value}</li>;
}

function NumberList(props) {
  const numbers = props.numbers;
  const listItems = numbers.map(number => (
    // 正确！key 应该在数组的上下文中被指定
    <ListItem key={number.toString()} value={number} />
  ));
  return <ul>{listItems}</ul>;
}
```

### 1.7 表单-受控组件

https://zh-hans.reactjs.org/docs/forms.html

#### 1.7.1 input

```jsx
class NameForm extends React.Component {
  constructor(props) {
    super(props);
    this.state = { value: '' };

    this.handleChange = this.handleChange.bind(this);
    this.handleSubmit = this.handleSubmit.bind(this);
  }

  handleChange(event) {
    this.setState({ value: event.target.value });
  }

  handleSubmit(event) {
    alert('提交的名字: ' + this.state.value);
    event.preventDefault();
  }

  render() {
    return (
      <form onSubmit={this.handleSubmit}>
        <label>
          名字:
          <input type="text" value={this.state.value} onChange={this.handleChange} />
        </label>
        <input type="submit" value="提交" />
      </form>
    );
  }
}
```

#### 1.7.2 textarea

```jsx
class EssayForm extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      value: '请撰写一篇关于你喜欢的 DOM 元素的文章.'
    };

    this.handleChange = this.handleChange.bind(this);
    this.handleSubmit = this.handleSubmit.bind(this);
  }

  handleChange(event) {
    this.setState({ value: event.target.value });
  }

  handleSubmit(event) {
    alert('提交的文章: ' + this.state.value);
    event.preventDefault();
  }

  render() {
    return (
      <form onSubmit={this.handleSubmit}>
        <label>
          文章:
          <textarea value={this.state.value} onChange={this.handleChange} />
        </label>
        <input type="submit" value="提交" />
      </form>
    );
  }
}
```

#### 1.7.3 select

```jsx
class FlavorForm extends React.Component {
  constructor(props) {
    super(props);
    this.state = { value: 'coconut' };

    this.handleChange = this.handleChange.bind(this);
    this.handleSubmit = this.handleSubmit.bind(this);
  }

  handleChange(event) {
    this.setState({ value: event.target.value });
  }

  handleSubmit(event) {
    alert('你喜欢的风味是: ' + this.state.value);
    event.preventDefault();
  }

  render() {
    return (
      <form onSubmit={this.handleSubmit}>
        <label>
          选择你喜欢的风味:
          <select value={this.state.value} onChange={this.handleChange}>
            <option value="grapefruit">葡萄柚</option>
            <option value="lime">酸橙</option>
            <option value="coconut">椰子</option>
            <option value="mango">芒果</option>
          </select>
        </label>
        <input type="submit" value="提交" />
      </form>
    );
  }
}
```



# Redux 数据管理

![image-20200331015911086](http://img.golang.space/PicGo/2020-04-01/16-58-48-image-20200331015911086.png)



![image-20200331020211453](http://img.golang.space/PicGo/2020-04-01/165928#image-20200331020211453.png)





- `state` 数据
- `store` 仓库
- `action` 修改 state
- `reducer` 触发 action 进行修改

```js
// project > index.js

import { createStore } from 'redux';

const counterReducer = (state = 0, action) => {
  switch (action.type) {
    case 'INCREMENT':
      return state + 1;
    default:
      return state;
  }
};

const store = createStore(counterReducer);

console.log(store.getState());

// 指派动作
store.dispatch({
  type: 'INCREMENT'
});
```

在 reducer 中不建议修改源数据, 使用以下方式复制数据

```js
let newState =  JSON.parse(JSON.stringify(state));
```



> demo

1  创建 store 存放应用状态

```js
// src -> store -> index.js
import { createStore } from 'redux';
import reducer from './reducer';

// 创建 Redux store 来存放应用的状态。
// API 是 { subscribe, dispatch, getState }。
const store = createStore(reducer, window.__REDUX_DEVTOOLS_EXTENSION__ && window.__REDUX_DEVTOOLS_EXTENSION__());

// 可以手动订阅更新，也可以事件绑定到视图层。
store.subscribe(() => console.log(store.getState()));
export default store;

```



2 创建 reducer

```js
// src -> store -> reducer.js
import * as types from './action';

const defaultState = {
  inputValue: 'Write Something',
  list: ['早上 8 点晨会, 分配今天的任务1', '早上 8 点晨会, 分配今天的任务2', '早上 8 点晨会, 分配今天的任务3']
};

export default (state = defaultState, action) => {
  switch (action.type) {
    case types.CHANGEINPUT:
      console.log('action', action);
      console.log('state', state);
      return Object.assign({}, state, { inputValue: action.value });
    default:
      return state;
  }
};
```



3 创建 actionTypes

```js
// src -> store -> actionTypes.js
export const CHANGEINPUT = 'CHANGEINPUT';
```



4 创建 actionCreates.js

```js
import * as types from './actionTypes';

export const ChangeInputAction = val => ({
  type: types.CHANGE_INPUT,
  val
});

export const AddListTile = () => ({
  type: types.ADD_LIST_TILE
});

export const DeleteItem = index => ({
  type: types.DELETE_ITEM,
  index
});
```





## 组件 ui  与业务逻辑拆分

创建业务逻辑与组件 ui,  使用 业务逻辑页面调用 组件

使用无状态组件有更好的性能, 无状态组件存放 ui



## 异步请求

```js
yarn add axios

import axios from 'axios'

axios.get('').then(()=>{
  console.log
})
```



![image-20201122163122366](http://img.golang.space/1606033893733-1606033882980-image-20201122163122366.png)